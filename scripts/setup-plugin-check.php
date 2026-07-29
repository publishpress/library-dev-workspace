#!/usr/bin/env php
<?php

declare(strict_types=1);

function show_help(): void
{
    echo "Set up WordPress.org Plugin Check for the current plugin.\n";
    echo "Usage: setup-plugin-check.php [--force] [--skip-composer-update] [--skip-workflow]\n";
    echo "\n";
    echo "Options:\n";
    echo "  -h, --help                 Display this help message.\n";
    echo "  --force                    Overwrite existing setup files.\n";
    echo "  --skip-composer-update     Do not run composer update after merging composer.json.\n";
    echo "  --skip-workflow            Do not copy the GitHub workflow template.\n";
}

/**
 * @return array<string, mixed>
 */
function read_json_file(string $path): array
{
    if (!is_file($path)) {
        fwrite(STDERR, "Error: File not found: {$path}\n");
        exit(1);
    }

    $data = json_decode((string) file_get_contents($path), true);
    if (!is_array($data)) {
        fwrite(STDERR, "Error: Invalid JSON in {$path}\n");
        exit(1);
    }

    return $data;
}

/**
 * @param array<string, mixed> $data
 */
function write_json_file(string $path, array $data): void
{
    $encoded = json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
    if ($encoded === false) {
        fwrite(STDERR, "Error: Failed to encode JSON for {$path}\n");
        exit(1);
    }

    file_put_contents($path, $encoded . "\n");
}

function resolve_dev_workspace_dir(string $repoRoot): string
{
    $vendorPath = $repoRoot . '/vendor/publishpress/dev-workspace';
    if (is_dir($vendorPath)) {
        return $vendorPath;
    }

    $localPath = dirname(__DIR__);
    if (is_file($localPath . '/composer.json')) {
        $composer = read_json_file($localPath . '/composer.json');
        if (($composer['name'] ?? '') === 'publishpress/dev-workspace') {
            return $localPath;
        }
    }

    fwrite(STDERR, "Error: publishpress/dev-workspace is not installed.\n");
    exit(1);
}

/**
 * @param array<int, array<string, mixed>> $repositories
 */
function has_plugin_check_repository(array $repositories): bool
{
    foreach ($repositories as $repository) {
        if (($repository['package']['name'] ?? '') === 'wordpress/plugin-check') {
            return true;
        }
    }

    return false;
}

/**
 * @param array<string, mixed> $composer
 * @param array<string, mixed> $fragment
 *
 * @return array{0: array<string, mixed>, 1: bool}
 */
function merge_plugin_check_composer(array $composer, array $fragment): array
{
    $changed = false;

    $composer['repositories'] = $composer['repositories'] ?? [];
    if (!has_plugin_check_repository($composer['repositories'])) {
        $composer['repositories'] = array_merge($fragment['repositories'] ?? [], $composer['repositories']);
        $changed = true;
    }

    $composer['extra'] = $composer['extra'] ?? [];
    $installerPaths = $composer['extra']['installer-paths'] ?? [];
    foreach ($fragment['extra']['installer-paths'] ?? [] as $path => $types) {
        if (!isset($installerPaths[$path])) {
            $installerPaths[$path] = $types;
            $changed = true;
        }
    }
    $composer['extra']['installer-paths'] = $installerPaths;

    $composer['config'] = $composer['config'] ?? [];
    $composer['config']['allow-plugins'] = $composer['config']['allow-plugins'] ?? [];
    if (($composer['config']['allow-plugins']['composer/installers'] ?? false) !== true) {
        $composer['config']['allow-plugins']['composer/installers'] = true;
        $changed = true;
    }

    return [$composer, $changed];
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
function build_plugin_review_ruleset(array $paths): string
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
    <rule ref="vendor/wordpress/plugin-check/phpcs-rulesets/plugin-review.xml"/>
</ruleset>

XML;
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
$skipComposerUpdate = in_array('--skip-composer-update', $argv, true);
$skipWorkflow = in_array('--skip-workflow', $argv, true);

$repoRoot = getcwd() ?: '';
if ($repoRoot === '' || !is_file($repoRoot . '/composer.json')) {
    fwrite(STDERR, "Error: Run this command from the plugin repository root.\n");
    exit(1);
}

$devWorkspaceDir = resolve_dev_workspace_dir($repoRoot);
$composerPath = $repoRoot . '/composer.json';
$composerFragmentPath = $devWorkspaceDir . '/templates/composer.plugin-check.json.dist';
$pluginReviewPath = $repoRoot . '/.phpcs-plugin-review.xml';
$workflowSource = $devWorkspaceDir . '/templates/github-workflows/plugin-check.yml.dist';
$workflowDestination = $repoRoot . '/.github/workflows/plugin-check.yml';

echo "Setting up Plugin Check for {$repoRoot}\n";

[$composer, $composerChanged] = merge_plugin_check_composer(
    read_json_file($composerPath),
    read_json_file($composerFragmentPath)
);

if ($composerChanged) {
    write_json_file($composerPath, $composer);
    echo "Updated: composer.json\n";
} else {
    echo "Skipped (already configured): composer.json\n";
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
    file_put_contents($pluginReviewPath, build_plugin_review_ruleset($scanPaths));
    echo ($existed ? 'Updated' : 'Created') . ": {$pluginReviewPath}\n";
}

if (!$skipWorkflow) {
    copy_file_if_needed($workflowSource, $workflowDestination, $force);
}

if ($composerChanged && !$skipComposerUpdate) {
    echo "Running composer update wordpress/plugin-check composer/installers...\n";
    passthru('composer update wordpress/plugin-check composer/installers --no-interaction 2>&1', $exitCode);
    if ($exitCode !== 0) {
        fwrite(STDERR, "Warning: composer update failed. Run it manually after reviewing composer.json.\n");
    }
} elseif (!$skipComposerUpdate && !is_dir($repoRoot . '/vendor/wordpress/plugin-check')) {
    echo "Running composer update wordpress/plugin-check composer/installers...\n";
    passthru('composer update wordpress/plugin-check composer/installers --no-interaction 2>&1', $exitCode);
    if ($exitCode !== 0) {
        fwrite(STDERR, "Warning: composer update failed. Run it manually.\n");
    }
}

echo "Plugin Check setup complete.\n";
