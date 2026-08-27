#!/usr/bin/env php
<?php

/**
 * Fixture tests for scripts/plugin-bump-version.php.
 *
 * Run: php test/plugin-bump-version-test.php
 */

$failures = 0;
$passes = 0;

function pass(string $name): void
{
    global $passes;
    $passes++;
    echo "PASS  {$name}\n";
}

function fail(string $name, string $detail): void
{
    global $failures;
    $failures++;
    echo "FAIL  {$name} — {$detail}\n";
}

function assertTrue(string $name, bool $condition, string $detail = ''): void
{
    if ($condition) {
        pass($name);
        return;
    }

    fail($name, $detail !== '' ? $detail : 'expected true');
}

function assertSame(string $name, $expected, $actual): void
{
    if ($expected === $actual) {
        pass($name);
        return;
    }

    fail($name, 'expected ' . var_export($expected, true) . ', got ' . var_export($actual, true));
}

function makeFixture(array $files): string
{
    $dir = sys_get_temp_dir() . '/pp-bump-' . bin2hex(random_bytes(8));
    mkdir($dir, 0777, true);

    foreach ($files as $relative => $contents) {
        $path = $dir . '/' . $relative;
        $parent = dirname($path);
        if (!is_dir($parent)) {
            mkdir($parent, 0777, true);
        }
        file_put_contents($path, $contents);
    }

    return $dir;
}

function defaultComposerJson(): string
{
    return json_encode(
        [
            'name' => 'publishpress/demo-plugin',
            'extra' => [
                'plugin-slug' => 'demo-plugin',
                'version-constant' => 'DEMO_PLUGIN_VERSION',
            ],
        ],
        JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES
    ) . "\n";
}

function defaultPluginFile(string $version = '1.0.0'): string
{
    return <<<PHP
<?php
/**
 * Plugin Name: Demo Plugin
 * Version: {$version}
 */

define('DEMO_PLUGIN_VERSION', '{$version}');

PHP;
}

function runBump(string $dir, string $version): array
{
    $script = dirname(__DIR__) . '/scripts/plugin-bump-version.php';
    $descriptors = [
        0 => ['pipe', 'r'],
        1 => ['pipe', 'w'],
        2 => ['pipe', 'w'],
    ];

    $env = [];
    foreach (getenv() as $key => $value) {
        $env[$key] = $value;
    }
    $env['PP_SOURCE_PATH'] = $dir;

    $process = proc_open(
        [PHP_BINARY, $script, $version],
        $descriptors,
        $pipes,
        $dir,
        $env
    );

    if (!is_resource($process)) {
        return [255, '', 'failed to start process'];
    }

    fclose($pipes[0]);
    $stdout = stream_get_contents($pipes[1]);
    $stderr = stream_get_contents($pipes[2]);
    fclose($pipes[1]);
    fclose($pipes[2]);
    $code = proc_close($process);

    return [$code, (string) $stdout, (string) $stderr];
}

function read(string $dir, string $relative): string
{
    return (string) file_get_contents($dir . '/' . $relative);
}

function extractHeader(string $php): string
{
    if (preg_match('/^\s*\*\s+Version:\s*(.+)$/m', $php, $matches)) {
        return trim($matches[1]);
    }

    return '';
}

function extractConstant(string $php): string
{
    if (preg_match("/define\\('DEMO_PLUGIN_VERSION', '([^']+)'\\);/", $php, $matches)) {
        return $matches[1];
    }

    return '';
}

function extractStableTag(string $readme): string
{
    if (preg_match('/^Stable tag:\s*(.+)$/m', $readme, $matches)) {
        return trim($matches[1]);
    }

    return '';
}

$script = dirname(__DIR__) . '/scripts/plugin-bump-version.php';
assertTrue('bumper script exists', is_file($script), $script);

// --- stable bump ---
$stableDir = makeFixture([
    'composer.json' => defaultComposerJson(),
    'demo-plugin.php' => defaultPluginFile('1.0.0'),
    'readme.txt' => "Stable tag: 1.0.0\n",
    'package.json' => "{\n  \"name\": \"demo-plugin\",\n  \"version\": \"1.0.0\"\n}\n",
]);
[$code, $stdout, $stderr] = runBump($stableDir, '1.2.0');
assertSame('stable exit code', 0, $code);
assertTrue('stable stdout mentions Stable tag', strpos($stdout, 'Stable tag') !== false, $stdout . $stderr);
$stablePlugin = read($stableDir, 'demo-plugin.php');
assertSame('stable header', '1.2.0', extractHeader($stablePlugin));
assertSame('stable constant', '1.2.0', extractConstant($stablePlugin));
assertSame('stable readme', '1.2.0', extractStableTag(read($stableDir, 'readme.txt')));
$stablePackage = json_decode(read($stableDir, 'package.json'), true);
assertSame('stable package.json', '1.2.0', $stablePackage['version'] ?? null);
$stableComposer = json_decode(read($stableDir, 'composer.json'), true);
assertTrue('stable composer.json has no version field', !isset($stableComposer['version']));

// --- semantic prereleases preserve Stable tag ---
$prereleaseVersions = [
    '3.111.1-beta1',
    '4.10.4-beta',
    '1.2.0-beta.1+build.7',
];

foreach ($prereleaseVersions as $prereleaseVersion) {
    $preDir = makeFixture([
        'composer.json' => defaultComposerJson(),
        'demo-plugin.php' => defaultPluginFile('1.0.0'),
        'readme.txt' => "Stable tag: 1.0.0\n",
        'package.json' => "{\n  \"name\": \"demo-plugin\",\n  \"version\": \"1.0.0\"\n}\n",
    ]);
    [$code, $stdout, $stderr] = runBump($preDir, $prereleaseVersion);
    $prefix = "prerelease {$prereleaseVersion}";
    assertSame("{$prefix} exit code", 0, $code);
    assertTrue(
        "{$prefix} stdout says Stable tag unchanged",
        strpos($stdout, 'Stable tag unchanged') !== false,
        $stdout . $stderr
    );
    $prePlugin = read($preDir, 'demo-plugin.php');
    assertSame("{$prefix} header", $prereleaseVersion, extractHeader($prePlugin));
    assertSame("{$prefix} constant", $prereleaseVersion, extractConstant($prePlugin));
    assertSame("{$prefix} readme preserved", '1.0.0', extractStableTag(read($preDir, 'readme.txt')));
    $prePackage = json_decode(read($preDir, 'package.json'), true);
    assertSame("{$prefix} package.json", $prereleaseVersion, $prePackage['version'] ?? null);
}

// --- invalid semantic versions leave files unchanged ---
$invalidVersions = [
    '4.10.4-beta..1',
    '01.2.3',
    '1.02.3',
    '1.2.03',
    '1.2.3-beta.01',
];

foreach ($invalidVersions as $invalidVersion) {
    $invalidDir = makeFixture([
        'composer.json' => defaultComposerJson(),
        'demo-plugin.php' => defaultPluginFile('1.0.0'),
        'readme.txt' => "Stable tag: 1.0.0\n",
    ]);
    [$code, $stdout, $stderr] = runBump($invalidDir, $invalidVersion);
    $prefix = "invalid {$invalidVersion}";
    assertSame("{$prefix} exit code", 1, $code);
    assertTrue(
        "{$prefix} message",
        strpos($stdout . $stderr, 'Invalid version format') !== false,
        $stdout . $stderr
    );
    $invalidPlugin = read($invalidDir, 'demo-plugin.php');
    assertSame("{$prefix} header unchanged", '1.0.0', extractHeader($invalidPlugin));
    assertSame("{$prefix} constant unchanged", '1.0.0', extractConstant($invalidPlugin));
    assertSame("{$prefix} readme unchanged", '1.0.0', extractStableTag(read($invalidDir, 'readme.txt')));
}

// --- missing plugin-slug ---
$missingSlugDir = makeFixture([
    'composer.json' => json_encode(['extra' => ['version-constant' => 'DEMO_PLUGIN_VERSION']]) . "\n",
    'demo-plugin.php' => defaultPluginFile(),
]);
[$code, $stdout, $stderr] = runBump($missingSlugDir, '1.2.0');
assertSame('missing slug exit code', 1, $code);
assertTrue(
    'missing slug message',
    strpos($stdout . $stderr, 'Plugin slug or version constant not found') !== false,
    $stdout . $stderr
);

// --- missing version-constant ---
$missingConstDir = makeFixture([
    'composer.json' => json_encode(['extra' => ['plugin-slug' => 'demo-plugin']]) . "\n",
    'demo-plugin.php' => defaultPluginFile(),
]);
[$code, $stdout, $stderr] = runBump($missingConstDir, '1.2.0');
assertSame('missing constant extra exit code', 1, $code);
assertTrue(
    'missing constant extra message',
    strpos($stdout . $stderr, 'Plugin slug or version constant not found') !== false,
    $stdout . $stderr
);

// --- package.json without version is left alone ---
$noPkgVersionDir = makeFixture([
    'composer.json' => defaultComposerJson(),
    'demo-plugin.php' => defaultPluginFile('1.0.0'),
    'readme.txt' => "Stable tag: 1.0.0\n",
    'package.json' => "{\n  \"name\": \"demo-plugin\"\n}\n",
]);
$originalPackage = read($noPkgVersionDir, 'package.json');
[$code] = runBump($noPkgVersionDir, '1.2.0');
assertSame('package.json without version exit code', 0, $code);
assertSame('package.json without version unchanged', $originalPackage, read($noPkgVersionDir, 'package.json'));

echo "\n{$passes} passed, {$failures} failed\n";
exit($failures > 0 ? 1 : 0);
