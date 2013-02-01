ringclear-cfml-client
=====================

A CFML client for [RingClear](http://ringclear.com)

A straight implementation of the various features of the RingClear SOAP API, with a couple convenience methods thrown in.  Available methods include:

* exportContacts
* importContacts
* deleteContacts
* deleteAllContacts
* createGroup
* addContactsToGroup
* deleteGroup
* exportGroups
* exportStandardGroups
* exportContactFields

**NOTE:** One thing not fully implemented is the method that generates the bit mask for message preferences. Right now it doesn't create bit masks for anything voice related and assumes SMS preferences are the same for both cell1 and cell2.  If you need to generate such bitmasks the values are included in a comment in the source.

Also included is a little CSV utility component that has a method for turning a CSV into a query (because RingClear returns CSV data).

