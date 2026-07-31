#!/usr/bin/env php
<?php

declare(strict_types=1);

const PLUGIN_REVIEW_RULESET = 'vendor/publishpress/publishpress-phpcs-standards/standards/plugin-check-rulesets/plugin-review.xml';

function show_help(): void
{
    echo "Set up WordPress.org Plugin Check for the current plugin.\n";
    echo "Usage: setup-plugin-check.php [--force] [--skip-workflow]\n";
    echo "\n";
    echo "Options:\n";
    echo "  -h, --help                 Display this help message.\n";
    echo "  --force                    Overwrite existing setup files.\n";
    echo "  --skip-workflow            Do not copy the GitHub workflow template.\n";
}

/**
 * @return list<string>
 */
function collect_phpcs_scan_paths(string $repoRoot): array
{
    $paths = [];
    $phpcsXml = $repoRoot . '/.phpcs.xml';

    if (is_file($phpcsXml)) {
        $xml = simplexml_load_file($phpcsXml);
        if ($xml !== false) {
            foreach ($xml->file as $file) {
                $path = trim((string) $file);
                if ($path !== '') {
                    $paths[] = $path;
                }
            }
        }
    }

    if (is_file($repoRoot . '/readme.txt') && !in_array('readme.txt', $paths, true)) {
        $paths[] = 'readme.txt';
    }

    return $paths;
}

/**
 * @param list<string> $paths
 */
function build_plugin_review_ruleset(array $paths, string $rulesetRef): string
{
    $fileLines = '';
    foreach ($paths as $path) {
        $fileLines .= "    <file>{$path}</file>\n";
    }

    return <<<XML
<?xml version="1.0"?>
<ruleset xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" name="PublishPressPluginReview"
         xsi:noNamespaceSchemaLocation="https://raw.githubusercontent.com/squizlabs/PHP_CodeSniffer/master/phpcs.xsd">
    <description>WordPress.org plugin review standards (Plugin Check)</description>

    <arg name="extensions" value="php"/>
    <arg name="colors"/>
    <arg name="cache"/>
    <ini name="memory_limit" value="256M"/>
    <arg name="basepath" value="."/>
    <arg name="parallel" value="20"/>
    <arg value="ps"/>
    <exclude-pattern>*/node_modules/*</exclude-pattern>
    <exclude-pattern>*/vendor/*</exclude-pattern>

{$fileLines}
    <rule ref="{$rulesetRef}"/>
</ruleset>

XML;
}

function resolve_dev_workspace_dir(string $repoRoot): string
{
    $vendorPath = $repoRoot . '/vendor/publishpress/dev-workspace';
    if (is_dir($vendorPath)) {
        return $vendorPath;
    }

    $localPath = dirname(__DIR__);
    if (is_file($localPath . '/composer.json')) {
        $composer = json_decode((string) file_get_contents($localPath . '/composer.json'), true);
        if (is_array($composer) && ($composer['name'] ?? '') === 'publishpress/dev-workspace') {
            return $localPath;
        }
    }

    fwrite(STDERR, "Error: publishpress/dev-workspace is not installed.\n");
    exit(1);
}

function copy_file_if_needed(string $source, string $destination, bool $force): bool
{
    if (is_file($destination) && !$force) {
        echo "Skipped (already exists): {$destination}\n";
        return false;
    }

    $destinationDir = dirname($destination);
    if (!is_dir($destinationDir) && !mkdir($destinationDir, 0775, true) && !is_dir($destinationDir)) {
        fwrite(STDERR, "Error: Could not create directory {$destinationDir}\n");
        exit(1);
    }

    if (!copy($source, $destination)) {
        fwrite(STDERR, "Error: Could not copy {$source} to {$destination}\n");
        exit(1);
    }

    echo "Created: {$destination}\n";
    return true;
}

if (in_array('-h', $argv, true) || in_array('--help', $argv, true)) {
    show_help();
    exit(0);
}

$force = in_array('--force', $argv, true);
$skipWorkflow = in_array('--skip-workflow', $argv, true);

$repoRoot = getcwd() ?: '';
if ($repoRoot === '' || !is_file($repoRoot . '/composer.json')) {
    fwrite(STDERR, "Error: Run this command from the plugin repository root.\n");
    exit(1);
}

$devWorkspaceDir = resolve_dev_workspace_dir($repoRoot);
$pluginReviewPath = $repoRoot . '/.phpcs-plugin-review.xml';
$workflowSource = $devWorkspaceDir . '/templates/github-workflows/plugin-check.yml.dist';
$workflowDestination = $repoRoot . '/.github/workflows/plugin-check.yml';
$pluginReviewRulesetPath = $repoRoot . '/' . PLUGIN_REVIEW_RULESET;

echo "Setting up Plugin Check for {$repoRoot}\n";

if (!is_file($pluginReviewRulesetPath)) {
    fwrite(STDERR, "Error: Plugin Check ruleset not found at " . PLUGIN_REVIEW_RULESET . ".\n");
    fwrite(STDERR, "Run composer update publishpress/publishpress-phpcs-standards.\n");
    exit(1);
}

$scanPaths = collect_phpcs_scan_paths($repoRoot);
if ($scanPaths === []) {
    fwrite(STDERR, "Error: No scan paths found. Add a .phpcs.xml file or create .phpcs-plugin-review.xml manually.\n");
    exit(1);
}

if (is_file($pluginReviewPath) && !$force) {
    echo "Skipped (already exists): {$pluginReviewPath}\n";
} else {
    $existed = is_file($pluginReviewPath);
    file_put_contents($pluginReviewPath, build_plugin_review_ruleset($scanPaths, PLUGIN_REVIEW_RULESET));
    echo ($existed ? 'Updated' : 'Created') . ": {$pluginReviewPath}\n";
}

if (!$skipWorkflow) {
    copy_file_if_needed($workflowSource, $workflowDestination, $force);
}

echo "Plugin Check setup complete.\n";
