#!/usr/bin/env php
<?php
// check-key.php
// Extracts the value of $config['des_key'] from a given PHP config file.
// Handles different quote types and basic PHP syntax.

if ($argc < 2) {
    error_log("Usage: check-key.php <config_file_path>");
    exit(1);
}

$configFile = $argv[1];

if (!file_exists($configFile) || !is_readable($configFile)) {
    // File not found or readable, echo nothing, let shell script handle empty return
    // error_log("Debug: Config file not found or not readable: " . $configFile);
    echo "";
    exit(0);
}

// Define $config array beforehand to avoid errors if file doesn't define it
$config = [];

// Use output buffering to suppress any output from the included file itself
ob_start();
// Suppress errors during include in case of syntax issues in user file
$include_result = @include($configFile); // Use include, not include_once, in case called multiple times? Safer with include.
ob_end_clean(); // Discard any output from the included file

if ($include_result === false) {
    error_log("Warning: Could not include/parse config file: " . $configFile);
    echo ""; // Return empty on parse error
    exit(0);
}

// Check if the key exists (works for 'des_key' or "des_key" if PHP parses it)
// and is a non-empty string
if (isset($config['des_key']) && is_string($config['des_key']) && $config['des_key'] !== '') {
    echo $config['des_key'];
    exit(0);
} else {
     // Key not found, not a string, or empty - echo nothing
    // error_log("Debug: \$config['des_key'] not found, not a string, or empty in " . $configFile);
    echo "";
    exit(0);
}
?>