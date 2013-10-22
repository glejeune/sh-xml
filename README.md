# sh-xml

A (very) naive XML parser for sh 

-- inspired by this StackOverflow Q/A : http://stackoverflow.com/questions/893585/how-to-parse-xml-in-bash

## Usage

First, copy `xml_parser.sh` in a place at your conveniance, then include it in your own script

    . /path/to/xml_parser.sh

To parse a XML file, you need to create a function in which all the informations of all XML entities found will be sent. Then, you juste have to call the `parse_xml`function with, as first parameter, the name of the "treatment" function created bellow and the path to the XML file, as second argument :

    do_xml() {
      # ...
    }
    parse_xml "do_xml" /path/to/the/file.xml

In this example, the `do_xml` function will be called for every XML entity. In **sh-xml**, an XML entity correspond to the current tag found, and the following content. So, in your treatment function, you have access to the following variables :

* `XML_ENTITY`: The current XML entity
* `XML_CONTENT` : Data found after the current XML entity
* `XML_TAG_NAME` : Name of the current tag. If the current tag is a close tag, the heading "/" is present in the tag name
* `XML_TAG_TYPE` : Type of the current tag. The value can be "OPEN", "CLOSE", "EMPTY", "COMMENT" or "INSTRUCTION"
* `XML_COMMENT` : If the current tag is of type "COMMENT", this variable contains the text of the comment
* `XML_PATH` : Full XPath path of the current tag

You can also use these helper function:

### `has_attribute` 

This function take, as first parameter, the name of an attribute, and indicate if it exist within the current XML entity. Thus, this function return `1` if the attribute exist, `0` otherwise.

**Example** 

    do_xml() {
      has_attribute "password"
      if [ "$?" = "1" ] ; then
        # do something with the current XML entity
      fi
    }

### `get_attribute_value` 

This function allow you to get the value of the attribute which name is passed as parameter

**Example**

    do_xml() {
      PASSWORD_VALUE=$(get_attribute_value "password")
      # Do something with PASSWORD_VALUE
    }

### `set_attribute_value`

This function allow you to set the value of the given attribute. If the attribute exist for the current XML entity, its value is updated.

**Example**

    do_xml() {
      set_attribute_value "password" "mYp4sSw0rD"
    }

### `print_entity`

This function allow you to print the current XML entity to stdout

**Example**
 
    print_xml() {
       print_entity
    }
    parse_xml "print_xml" /path/to/sample.xml

### `terminate_parser`

Terminate parsing. The end of the XML file will not be read.

**Example**

    do_xml() {
      if [ "$XML_PATH" = "/stop/reading/here" ] ; then
        # You can either access all data for this entity
        terminate_parser
      end
    }

## Tests

This project use [shUnit2](https://code.google.com/p/shunit2/) to perform unit tests. Just run `make` to run the tests suite. All tests are in the `tests` directory. 

