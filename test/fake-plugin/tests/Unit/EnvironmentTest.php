<?php

declare(strict_types=1);

namespace Tests\Unit;

use Codeception\Test\Unit;

/**
 * Lightweight unit tests (no WordPress bootstrap), same pattern as PublishPress Future.
 */
final class EnvironmentTest extends Unit
{
    public function testPhpVersionMeetsMinimum(): void
    {
        $this->assertGreaterThanOrEqual(70400, PHP_VERSION_ID);
    }
}
