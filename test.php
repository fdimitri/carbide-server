<?php

class testClass {
    protected $settings;
    function __constructor($blah) {
        return($blah);
    }    function getSettings() {
        return($this->settings);
    }
}


$tc = new testClass();
$tv = new testClass("boo");

$tc->getSettings();

$tc->getSettings();



$tc = new testClass();

$tc->getSettings();



?>