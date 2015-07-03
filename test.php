<?php

class testClass {
    protected $settings;
    function getSettings() {
        return($this->settings);
    }
}


$tc = new testClass();

$tc->getSettings();

$tc = new testClass();

$tc->getSettings();


?>

