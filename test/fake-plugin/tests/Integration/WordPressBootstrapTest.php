<?php

declare(strict_types=1);

namespace Tests\Integration;

use lucatume\WPBrowser\TestCase\WPTestCase;

/**
 * Integration tests with WPLoader (MySQL + dump.sql), aligned with PublishPress Future.
 */
final class WordPressBootstrapTest extends WPTestCase
{
    public function testFactoryCreatesPost(): void
    {
        $post = static::factory()->post->create_and_get();

        $this->assertInstanceOf(\WP_Post::class, $post);
    }

    public function testFakePluginIsActive(): void
    {
        $this->assertTrue(is_plugin_active('fake-plugin/fake-plugin.php'));
    }
}
