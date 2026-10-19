#!/usr/bin/env php
<?php

/**
 * Fixture tests for scripts/longpath.
 *
 * Run: php test/longpath-test.php
 */

$failures = 0;
$passes = 0;
$script = dirname(__DIR__) . '/scripts/longpath';

function pass($name)
{
    global $passes;
    $passes++;
    echo "PASS  {$name}\n";
}

function fail($name, $detail)
{
    global $failures;
    $failures++;
    echo "FAIL  {$name} — {$detail}\n";
}

function runLongpath($args)
{
    global $script;
    $command = 'php ' . escapeshellarg($script);
    foreach ($args as $arg) {
        $command .= ' ' . escapeshellarg($arg);
    }
    $command .= ' 2>&1';

    $output = array();
    $status = 0;
    exec($command, $output, $status);

    return array($status, implode("\n", $output));
}

function makeTree($root)
{
    $paths = array(
        'short.txt',
        'nested/directories/create/longer/paths/deep_file.txt',
        'nested/directories/create/longer/paths/another_very_long_filename_to_test_path_length_calculations.txt',
        'test/should_be_skipped.txt',
        'dist/skip_this_too.txt',
        'dev-workspace/another_skipped.txt',
        'node_modules/package/should_be_ignored.txt',
        'kept/real-file.php',
    );

    foreach ($paths as $relative) {
        $full = $root . '/' . $relative;
        $parent = dirname($full);
        if (!is_dir($parent) && !mkdir($parent, 0777, true) && !is_dir($parent)) {
            throw new RuntimeException('Failed to create ' . $parent);
        }
        if (file_put_contents($full, "x\n") === false) {
            throw new RuntimeException('Failed to write ' . $full);
        }
    }
}

list($status, $output) = runLongpath(array('-h'));
if ($status === 0 && strpos($output, 'Usage: longpath DIRECTORY [NUMBER_OF_PATHS]') === 0) {
    pass('help');
} else {
    fail('help', "status={$status} output={$output}");
}

$missing = sys_get_temp_dir() . '/longpath-missing-' . getmypid();
list($status, $output) = runLongpath(array($missing));
if ($status === 1 && strpos($output, 'Directory does not exist') !== false) {
    pass('missing directory');
} else {
    fail('missing directory', "status={$status} output={$output}");
}

$base = sys_get_temp_dir() . '/longpath-' . getmypid();
$scan = $base . '/dist/plugin-folder';
makeTree($scan);

list($status, $output) = runLongpath(array($scan));
$lines = explode("\n", $output);
$firstPath = isset($lines[1]) ? $lines[1] : '';
if ($status === 0 && strpos($firstPath, 'another_very_long_filename_to_test_path_length_calculations.txt') !== false) {
    pass('longest path under dist/plugin-folder');
} else {
    fail('longest path under dist/plugin-folder', $output);
}

$skipped = array('/test/', '/dist/', '/dev-workspace/', '/node_modules/');
$leak = '';
foreach ($lines as $line) {
    if (strpos($line, 'Length:') !== 0) {
        continue;
    }
    foreach ($skipped as $fragment) {
        if (strpos($line, $fragment) !== false) {
            $leak = $line;
            break 2;
        }
    }
}
if ($leak === '') {
    pass('skips nested ignored directories');
} else {
    fail('skips nested ignored directories', $leak);
}

list($status, $output) = runLongpath(array($scan, '3'));
$count = 0;
foreach (explode("\n", $output) as $line) {
    if (strpos($line, 'Length:') === 0) {
        $count++;
    }
}
if ($status === 0 && $count === 3) {
    pass('respects result count');
} else {
    fail('respects result count', "status={$status} count={$count} output={$output}");
}

echo "\n{$passes} passed, {$failures} failed\n";
exit($failures === 0 ? 0 : 1);
