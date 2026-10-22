<?php
/**
 * Plugin Name: Fake Plugin
 * Plugin URI:  https://publishpress.com
 * Description: A minimal fake WordPress plugin used to test publishpress/dev-workspace locally.
 * Version:     1.0.0
 * Author:      PublishPress
 * License:     GPL-2.0-or-later
 * Text Domain: fake-plugin
 */

defined('ABSPATH') || exit;

define('FAKE_PLUGIN_VERSION', '1.0.0');

/**
 * Demo strings covering common WordPress i18n patterns (gettext, contexts, plurals, placeholders).
 *
 * @return string[]
 */
function fake_plugin_i18n_demo_strings()
{
    $out   = [];
    $count = 42;

    // Plain gettext.
    $out[] = __('This is the first sample string for plain gettext.', 'fake-plugin');
    $out[] = __('This is the second sample string for plain gettext.', 'fake-plugin');
    $out[] = __('This is the third sample string for plain gettext.', 'fake-plugin');

    // Echo helpers (captured for concat output).
    ob_start();
    _e('This sentence is printed with gettext using immediate echo.', 'fake-plugin');
    $out[] = ob_get_clean();

    ob_start();
    esc_html_e('This line uses esc_html_e so unsafe markup cannot break the layout.', 'fake-plugin');
    $out[] = ob_get_clean();

    ob_start();
    esc_attr_e('This value uses esc_attr_e and belongs inside an HTML attribute.', 'fake-plugin');
    $out[] = ob_get_clean();

    // Returning wrapped variants (typical for attributes / safe HTML).
    $out[] = esc_html__('This line uses esc_html__ and returns a value instead of echoing it.', 'fake-plugin');
    $out[] = esc_attr__('This line uses esc_attr__ for text stored in an attribute.', 'fake-plugin');

    // Same surface string, different meaning (classic disambiguation for translators).
    $out[] = _x(
        'Record',
        'Button label: start recording audio or video.',
        'fake-plugin'
    );
    $out[] = _x(
        'Record',
        'Noun: a single audio or video recording you can play back.',
        'fake-plugin'
    );

    ob_start();
    _ex(
        'Leave',
        'Button label: close the dialog without keeping changes.',
        'fake-plugin'
    );
    $out[] = ob_get_clean();

    // Plural forms + number substitution.
    $out[] = sprintf(
        // translators: %d: number of items
        _n(
            'There is %d item in this plural-form test.',
            'There are %d items in this plural-form test.',
            $count,
            'fake-plugin'
        ),
        number_format_i18n($count)
    );

    $out[] = sprintf(
        // translators: %s: number of messages
        _nx(
            'You have %d message that needs gettext context.',
            'You have %d messages that need gettext context.',
            3,
            'Count of admin notices about translation tests.',
            'fake-plugin'
        ),
        number_format_i18n(3)
    );

    $out[] = sprintf(
        // translators: %s: a short word inserted into the sentence
        __('This sentence has one slot for a word: today we say %s.', 'fake-plugin'),
        'hello'
    );

    $out[] = sprintf(
        // translators: %1$s: earlier phrase, %2$s: later phrase (translators may reorder)
        __('We name two things in source order: first %1$s, then %2$s.', 'fake-plugin'),
        'sunrise',
        'sunset'
    );

    $out[] = sprintf(
        // translators: %1$s and %2$s appear out of numerical order on purpose
        __('The later clause mentions %2$s before the earlier clause mentions %1$s.', 'fake-plugin'),
        'winter',
        'spring'
    );

    // --- Regression-style cases for numbered placeholders (translator / PO tooling) ---
    $out[] = sprintf(
        // translators: %1$s is the product name, %2$s is the star rating markup or label
        __('If you like %1$s, please leave us a %2$s rating. Thank you!', 'fake-plugin'),
        'Fake Plugin',
        '★★★★★'
    );

    $out[] = sprintf(
        // translators: %s: module title — control next to %1$s/%2$s strings (issue #81 compares these)
        __('About %s', 'fake-plugin'),
        'this module'
    );

    $out[] = sprintf(
        // translators: %1$s: name, %2$s: place, %3$s: time word (order may change per language)
        __('Meet %1$s from %2$s at %3$s.', 'fake-plugin'),
        'Ada',
        'Lagos',
        'noon'
    );

    $out[] = sprintf(
        // translators: %1$d: count, %2$s: unit label
        __('We counted %1$d items and labeled the batch as %2$s.', 'fake-plugin'),
        12,
        'trial run'
    );

    $out[] = sprintf(
        // translators: Numbered placeholders split across a line break in the source (multiline msgid).
        __(
            'The first line names %1$s,' . "\n" . 'and the second line names %2$s.',
            'fake-plugin'
        ),
        'alpha',
        'beta'
    );

    ob_start();
    printf(
        // translators: %d: a whole number in a test phrase
        __('The integer placeholder in this test reads exactly %d.', 'fake-plugin'),
        7
    );
    $out[] = ob_get_clean();

    // Double-quoted string with an apostrophe inside (extractor/escape edge case).
    $out[] = __(
        'Quotes inside one string can mix apostrophes and double quotes, like it\'s short and "quoted".',
        'fake-plugin'
    );

    // Literal newlines inside a single msgid.
    $out[] = __(
        "This message is split across two lines in the source file.\nPlease translate it as one natural sentence, not two separate labels.",
        'fake-plugin'
    );

    return $out;
}

foreach (fake_plugin_i18n_demo_strings() as $chunk) {
    echo $chunk;
}
