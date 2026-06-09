<?php

unset($CFG);
global $CFG;
$CFG = new stdClass();

$CFG->dbtype = getenv("MOODLE_DB_TYPE") ?: "mariadb";
$CFG->dbhost = getenv("MOODLE_DB_HOST") ?: "127.0.0.1";
$CFG->dbname = getenv("MOODLE_DB_NAME") ?: "moodle";
$CFG->dbuser = getenv("MOODLE_DB_USER") ?: "moodleuser";
$CFG->dbpass = getenv("MOODLE_DB_PASS") ?: "change_me_db";
$CFG->prefix = getenv("MOODLE_DB_PREFIX") ?: "mdl_";

$CFG->dboptions = [
    "dbpersist" => false,
    "dbport" => getenv("MOODLE_DB_PORT") ?: "",
    "dbsocket" => false,
    "dbcollation" => "utf8mb4_unicode_ci",
];

$wwwroot = getenv("MOODLE_WWWROOT") ?: "http://localhost";
$http_port = getenv("MOODLE_DB_PORT") ?: "";

if (!empty($http_port) && $http_port !== "80" && $http_port !== "443") {
    if (strpos($wwwroot, ":" . $http_port) === false) {
        $wwwroot = rtrim($wwwroot, "/") . ":" . $http_port;
    }
}

$CFG->wwwroot = $wwwroot;

$CFG->dataroot = "/var/moodledata";

$CFG->directorypermissions = 0777;

$CFG->admin = "admin";

if (getenv("MOODLE_REVERSE_PROXY") === "true") {
    $CFG->reverseproxy = true;
}

if (getenv("MOODLE_DEBUG") === "true") {
    @error_reporting(E_ALL | E_STRICT);
    @ini_set("display_errors", "1");
    $CFG->debug = E_ALL | E_STRICT;
    $CFG->debugdisplay = 1;
}

if (getenv("JOBE_HOST")) {
    $CFG->forced_plugin_settings["qtype_coderunner"] = [
        "jobe_host" => getenv("JOBE_HOST"),
        "jobe_apikey" => getenv("JOBE_API_KEY") ?: "",
    ];
}

require_once __DIR__ . "/lib/setup.php";
