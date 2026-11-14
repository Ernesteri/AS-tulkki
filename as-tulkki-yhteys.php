<?php
/**
 * Plugin Name: AS tulkki – tiedonsiirto
 * Description: AS2026:n ja AS tulkin kilpailutietojen ja tulkintojen rajapinta.
 * Version: 0.7.2
 * Requires at least: 6.5
 * Requires PHP: 8.1
 * License: GPL-2.0-or-later
 */
defined('ABSPATH') || exit;
define('AS_TULKKI_PLUGIN_FILE', __FILE__);
require_once __DIR__ . '/includes/validation.php';
require_once __DIR__ . '/includes/management.php';
require_once __DIR__ . '/includes/plugin.php';
register_activation_hook(__FILE__, ['AS_Tulkki_Yhteys', 'install']);
add_action('plugins_loaded', ['AS_Tulkki_Yhteys', 'boot']);



