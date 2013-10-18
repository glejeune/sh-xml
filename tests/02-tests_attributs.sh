#!/bin/sh

TEST_PATH=$(dirname $(readlink -f $0))


# -- Tests

oneTimeSetUp() {
  XML_TEST_FILE=$TEST_PATH/sample.xml
}

do_xml_test_attr() {
  has_attribute "name"
  if [ $? = 1 ] && [ "$XML_PATH" = "/domain/property" ] && [ "$(get_attribute_value "name")" = "password" ]; then
    OLD_PASSWORD=$(get_attribute_value "value")
  	set_attribute_value "value" "mYn3ws3cr3tp4ssw0rd"
    NEW_PASSWORD=$(get_attribute_value "value")
  fi
}
testAttr() {
  OLD_PASSWORD="-"
  NEW_PASSWORD="-"
  parse_xml "do_xml_test_attr" $XML_TEST_FILE
  assertEquals "s3cr3t p4ss" "$OLD_PASSWORD"
  assertEquals "mYn3ws3cr3tp4ssw0rd" "$NEW_PASSWORD"
}

# load shunit2
. $TEST_PATH/test_helper 
test_init $0

