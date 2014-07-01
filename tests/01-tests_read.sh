#!/bin/sh

TEST_PATH=$(dirname $0)


# -- Tests

oneTimeSetUp() {
  XML_TEST_FILE=$TEST_PATH/sample.xml
}

do_xml_test_read() {
  WAS_IN_DO_XML_READ=1
  [ "$XML_PATH" = "/domain" ] && DOMAIN_FOUND=1
  [ "$XML_PATH" = "/domain/text" ] && DOMAIN_TEXT_FOUND=1
  [ "$XML_PATH" = "/domain/property" ] && DOMAIN_PROPERTY_FOUND=1
  [ "$XML_PATH" = "/domain/data" ] && DOMAIN_DATA_FOUND=1
  [ "$XML_PATH" = "/domain/data/format" ] && DOMAIN_DATA_FORMAT_FOUND=1
}
testRead() {
  WAS_IN_DO_XML_READ=0
  DOMAIN_FOUND=0
  DOMAIN_TEXT_FOUND=0
  DOMAIN_PROPERTY_FOUND=0
  DOMAIN_DATA_FOUND=0
  DOMAIN_DATA_FORMAT_FOUND=0

  parse_xml "do_xml_test_read" $XML_TEST_FILE
  assertEquals 1 $WAS_IN_DO_XML_READ
  assertEquals 1 $DOMAIN_FOUND
  assertEquals 1 $DOMAIN_TEXT_FOUND
  assertEquals 1 $DOMAIN_PROPERTY_FOUND
  assertEquals 1 $DOMAIN_DATA_FOUND
  assertEquals 1 $DOMAIN_DATA_FORMAT_FOUND
}

# load shunit2
. $TEST_PATH/test_helper 
test_init $0

