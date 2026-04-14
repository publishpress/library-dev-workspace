/**
 * Sample strings for JS translation tests (wp i18n make-pot / JSON).
 */
( function () {
	if ( typeof wp === 'undefined' || ! wp.i18n ) {
		return;
	}

	wp.i18n.__( 'Fake Plugin main script loaded.', 'fake-plugin' );
	wp.i18n.__( 'Save changes from the main panel.', 'fake-plugin' );
	wp.i18n._x( 'Close', 'Button label in main script', 'fake-plugin' );
    // translators: %d: number of items
	wp.i18n._n(
		'One item selected in the main view.',
		'%d items selected in the main view.',
		0,
		'fake-plugin'
	);
} )();
