/**
 * Sample strings for JS translation tests (wp i18n make-pot / JSON).
 */
( function () {
	if ( typeof wp === 'undefined' || ! wp.i18n ) {
		return;
	}

	wp.i18n.__( 'Open the fake plugin menu.', 'fake-plugin' );
	wp.i18n.__( 'Settings for the fake plugin.', 'fake-plugin' );
	wp.i18n._x( 'Menu', 'Admin sidebar navigation label', 'fake-plugin' );
} )();
