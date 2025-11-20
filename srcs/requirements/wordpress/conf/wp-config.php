<?php
define( 'DB_NAME', getenv('DB_NAME'));
define( 'DB_USER', getenv('DB_USER'));
define( 'DB_PASSWORD', file_get_contents('/run/secrets/db_password') );
define( 'DB_HOST', getenv('DB_HOST'));
define( 'WP_HOME', getenv('WP_FULL_URL'));
define( 'WP_SITEURL', getenv('WP_FULL_URL'));


// Debug settings for troubleshooting
define('WP_DEBUG', true);
define('WP_DEBUG_LOG', true);
define('WP_DEBUG_DISPLAY', false);

define( 'AUTH_KEY',         'put your unique phrase here' );
define( 'SECURE_AUTH_KEY',  'put your unique phrase here' );
define( 'LOGGED_IN_KEY',    'put your unique phrase here' );
define( 'NONCE_KEY',        'put your unique phrase here' );

define('WP_DEBUG', false);

$table_prefix = 'wp_';
if ( !defined('ABSPATH') )
    define('ABSPATH', dirname(__FILE__) . '/');

require_once(ABSPATH . 'wp-settings.php');
