#!/usr/bin/php
<?php

/**
 * Bump plugin version metadata for consuming PublishPress plugins.
 *
 * Updates the main plugin header and version constant always. Updates
 * package.json when it already defines version. Updates readme.txt Stable tag
 * for stable x.y.z versions only. Does not write a Composer version field.
 */

$basePath = getenv('PP_SOURCE_PATH');
if (!is_string($basePath) || $basePath === '' || !is_dir($basePath)) {
    $basePath = is_dir('/project') ? '/project' : (string) getcwd();
}

define('BASE_PATH', $basePath);
define('COMPOSER_JSON_PATH', BASE_PATH . '/composer.json');

function getExtraInfoFromComposerJson($composerJsonPath): array
{
    if (!is_file($composerJsonPath)) {
        fwrite(STDERR, "composer.json not found in " . BASE_PATH . "\n");
        exit(1);
    }

    $composerJson = json_decode((string) file_get_contents($composerJsonPath), true);
    if (!is_array($composerJson)) {
        fwrite(STDERR, "composer.json is not valid JSON\n");
        exit(1);
    }

    return $composerJson['extra'] ?? [];
}

function isStableVersion($version): bool
{
    return (bool) preg_match('/^\d+\.\d+\.\d+$/', $version);
}

function isValidVersion($version): bool
{
    return (bool) preg_match(
        '/^(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)' .
        '(?:-(?:0|[1-9]\d*|\d*[A-Za-z-][0-9A-Za-z-]*)' .
        '(?:\.(?:0|[1-9]\d*|\d*[A-Za-z-][0-9A-Za-z-]*))*)?' .
        '(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?\z/',
        $version
    );
}

function getCurrentVersion(): string
{
    return (string) exec('pversion');
}

function askForNewVersion(): string
{
    $currentVersion = getCurrentVersion();

    echo "Current version: " . $currentVersion . "\n";

    $newVersion = readline("Enter new version: ");

    return (string) $newVersion;
}

function mainPluginFilePath(): string
{
    return BASE_PATH . '/' . PLUGIN_SLUG . '.php';
}

function readMainPluginFile(): string
{
    $mainPluginFilePath = mainPluginFilePath();
    if (!is_file($mainPluginFilePath)) {
        fwrite(STDERR, "Main plugin file not found: {$mainPluginFilePath}\n");
        exit(1);
    }

    return (string) file_get_contents($mainPluginFilePath);
}

function updateVersionConstantInMainPluginFile($versionConstant, $newVersion): void
{
    $mainPluginFilePath = mainPluginFilePath();
    $mainPluginFile = readMainPluginFile();

    $updated = preg_replace(
        "/define\('{$versionConstant}', '.*?'\);/",
        "define('{$versionConstant}', '" . $newVersion . "');",
        $mainPluginFile,
        1,
        $count
    );

    if (!is_string($updated) || $count !== 1) {
        fwrite(STDERR, "Version constant {$versionConstant} not found in {$mainPluginFilePath}\n");
        exit(1);
    }

    file_put_contents($mainPluginFilePath, $updated);
}

function updateVersionInMainPluginFileHeader($newVersion): void
{
    $mainPluginFilePath = mainPluginFilePath();
    $mainPluginFile = readMainPluginFile();

    $updated = preg_replace(
        '/\*\s+Version: .*/',
        '* Version: ' . $newVersion,
        $mainPluginFile,
        1,
        $count
    );

    if (!is_string($updated) || $count !== 1) {
        fwrite(STDERR, "Version header not found in {$mainPluginFilePath}\n");
        exit(1);
    }

    file_put_contents($mainPluginFilePath, $updated);
}

function updateVersionInReadme($newVersion): void
{
    $readmeFilePath = BASE_PATH . '/readme.txt';
    if (!is_file($readmeFilePath)) {
        return;
    }

    $readmeFile = (string) file_get_contents($readmeFilePath);
    $updated = preg_replace(
        '/Stable tag: .*/',
        'Stable tag: ' . $newVersion,
        $readmeFile,
        1,
        $count
    );

    if (!is_string($updated) || $count !== 1) {
        fwrite(STDERR, "Stable tag not found in {$readmeFilePath}\n");
        exit(1);
    }

    file_put_contents($readmeFilePath, $updated);
}

function updateVersionInPackageJson($newVersion): void
{
    $packageJsonPath = BASE_PATH . '/package.json';
    if (!is_file($packageJsonPath)) {
        return;
    }

    $decoded = json_decode((string) file_get_contents($packageJsonPath), true);
    if (!is_array($decoded)) {
        fwrite(STDERR, "package.json is not valid JSON\n");
        exit(1);
    }

    if (!array_key_exists('version', $decoded)) {
        return;
    }

    $contents = (string) file_get_contents($packageJsonPath);
    $updated = preg_replace(
        '/("version"\s*:\s*")([^"]*)(")/',
        '${1}' . $newVersion . '${3}',
        $contents,
        1,
        $count
    );

    if (!is_string($updated) || $count !== 1) {
        fwrite(STDERR, "Failed to update version in package.json\n");
        exit(1);
    }

    file_put_contents($packageJsonPath, $updated);
}

$extra = getExtraInfoFromComposerJson(COMPOSER_JSON_PATH);
define('PLUGIN_SLUG', $extra['plugin-slug'] ?? '');
define('VERSION_CONSTANT', $extra['version-constant'] ?? '');

if (empty(PLUGIN_SLUG) || empty(VERSION_CONSTANT)) {
    echo "Plugin slug or version constant not found in composer.json\n";
    exit(1);
}

if (isset($argv[1])) {
    $newVersion = $argv[1];
} else {
    $newVersion = askForNewVersion();
}

if (!isValidVersion($newVersion)) {
    echo "Invalid version format. Please use semantic versioning (for example, x.y.z or x.y.z-beta1)\n";
    exit(1);
}

define('NEW_VERSION', $newVersion);

updateVersionInMainPluginFileHeader(NEW_VERSION);
updateVersionConstantInMainPluginFile(VERSION_CONSTANT, NEW_VERSION);

if (isStableVersion(NEW_VERSION)) {
    updateVersionInReadme(NEW_VERSION);
    echo "Updated plugin header, version constant, and Stable tag to " . NEW_VERSION . "\n";
} else {
    echo "Updated plugin header and version constant to " . NEW_VERSION . " (readme Stable tag unchanged)\n";
}

updateVersionInPackageJson(NEW_VERSION);
