# Overview

Media Manager provides users and authors within Movable Type 
and Melody with the ability to search and insert media from
a number of popular remote services like Amazon and YouTube. 
Using Media Manager one can open a dialog, enter a few search 
terms, select the book, DVD or video and optionally insert it
into a blog post. 

Once the media item has been selected it is automatically 
inserted into Movable Type or Melody's asset management system
and can be view by going to "Manage Assets" under the Manage 
menu.

# Installation

To install this plugin follow the instructions found here:

http://tinyurl.com/easy-plugin-install

**Prerequisites**

Keep in mind that before installing Media Manager you need to
make sure you have:

* Movable Type 4.01 or greater.
* Net::Amazon 
* Digest::SHA1

# Using the Plugin

To add an item from Amazon to your list of Assets, select "Amazon
Item" from the Create menu and follow the instructions. Adding an 
item from Amazon to a post is done exactly like inserting any other
asset.

# Template Tags

For the most part, Media Manager does not yet expose any template tags 
of its own. The only template tags exposes by this plugin are specifically
for interfacing with Amazon's API. 

## AmazonItemSearch

AmazonItemSearch is a container tag and is responsible for conducting
virtually all searches against Amazon's Marketing/Product API. Using this
container tag you can search for Books, DVDs, or any product in their 
catalog, as well wishlists and more.

The arguments/attributes this template tag supports is drawn directly
from the Net::Amazon. In fact, all of the search parameters supported by
Net::Amazon's search() method are supported as attributed by this tag.
This tag can be used to search for a specific item (e.g. by UPC or ASIN
ID), or a group of items (e.g. by keyword or category).

For example, here are *some* of the search parameters supported by
Net::Amazon (for a complete list please visit Net::Amazon's homepage). 

* `asin` - Returns a single item identified by its ASIN (or Amazon ID). 
* `actor` - Return items starring an actor (or actress!). This is useful
  for video. Can return many results.
* `artist` - Return items created by an artist. This is useful for music. 
  Can return many results.
* `author` - Search for items created by the specified author. This is
  useful for books obviously. Can return many results.
* `browsenode` - Returns a list of items by category ID (node). For example 
  node "4025" is the CGI books category. You can add a keywords parameter 
  to filter the results by that keyword.
* `exchange` - Returns an item offered by a third-party seller. The item is 
  referenced by the so-called exchange ID.
* `keyword` (or `keywords`) - Search by keyword, mandatory parameters `keyword` and `mode`. 
  Can return many results.
* `wishlist` - Search for all items in a specified wishlist. Can return 
  many results.
* `upc` - Music search by UPC (product barcode), mandatory parameter upc. 
  `mode` has to be set to music. Returns at most one result.
* `isbn` - Book search by ISBN (International Standard Book Number), 
  mandatory parameter isbn. Returns at most one result. When searching 
  non-US locales use the 13-digit ISBN.
* `similar` - Search for all items similar to the one represented by the ASIN 
  provided. Can return many results.
* `blended` - Initiate a search for items in all categories.
* `seller` - Start a search on items sold by a specific third-party seller, 
  referenced by its ID (not seller name).
* `mode` - The catalog by which to restrict your search. Common values are:
  Books, DVD, DigitalMusic, Merchants, VHS, and Video. A complete list can be
  found on Amazon's web site.

You can even combine the attributes to create compound searches. For example, 
to search for all *books* about "Blogging" you would use this tag:

    <mt:AmazonItemSearch mode="book" keyword="blogging">
      <mt:if name="__first__"><ul></mt:if>
      <li><$mt:AmazonTitle$></li>
      <mt:if name="__last__"></ul></mt:if>
    </mt:AmazonItemSearch>

## AmazonASIN

Return the ASIN of the current Amazon product or item in context. This must be
contained by the AmazonItemSearch tag.

## AmazonTitle

Return the title or product name of the current Amazon product or item in context. 
This must be contained by the AmazonItemSearch tag.

## AmazonDetailPageURL

Return the URL to the product currently in context. This URL will contain your
Amazon associates ID if you have specified one. This must be contained by the 
AmazonItemSearch tag.


## AmazonProductGroup

Return the product group of the item currently in context. This must be contained 
by the AmazonItemSearch tag.

## AmazonImageTag

This returns a complete HTML tag referring the image associated with the current 
item in context. A user can optionally specify the size of the image they would 
like returned. The following values are allowed to be used in the size attribute:

* thumb
* small
* medium
* large

For example, the following template tag:

    <$mt:AmazonImageTag size="small"$>

Returns the following HTML:

    <img src="URL" width="WIDTH" height="HEIGHT" alt="ITEM TITLE" />

## AmazonCustomImageURL

Amazon has a robust system for transforming images in the catalog in a number of 
different ways. Through this mechanism users can:

* blur an image
* rotate an image
* specify the exact width of an image
* add a drop shadow to the image
* and more

To make it easier to tweak images in these ways, the CustomImageURL tag was 
created. It accepts the following attributes:

* `size` - small|medium|large|thumb
* `width` -
* `blur` - 0-100, where 0 is clear, and 100 is blurry as hell
* `rotate` -
* `shadow` - left|right, to display a drop shadow on the left and right side respectively
* `percent` - 0-100, to display a "45% off" pill on the image
* `percent_loc` - left|right to display the "percent off pill" in the lower left, or 
  lower right hand corner respectively

## AmazonPrice

This returns the price of the current item. Amazon of course sells multiple 
version of an item. One can buy an item used or new. To specify which price 
you would like to display on your weblog use the type attribute. Acceptable 
values are:

* New
* Used
* Refurbished
* Consult Amazon's Web services documentation for a complete list

For example:

    <$mt:AmazonPrice type="New"$>

The price that is returned is "formatted." In other words, it contains a 
currency character (like the dollar, pound, or euro sign), and the necessary 
decimals.

## AmazonItemProperty 

This is one of the more powerful template tags provided by Media Manager for
Amazon, as it provides direct access to any attribute or property that a
product might have. The list of all of these properties is not listed here
because it is an extensive list. The best place to look for these properties
can be found at the [Net::Amazon](http://search.cpan.org/dist/Net-Amazon/)
homepage. When you click through you will see a bunch of links to modules 
like:

* Net::Amazon::Property
* Net::Amazon::Property::Book
* Net::Amazon::Property::CE
* Net::Amazon::Property::DVD
* Net::Amazon::Property::Music
* Net::Amazon::Property::Software
* Net::Amazon::Property::VideoGames

These modules each document the list of properties associated with each
product/media type. Let's look at an example. The media type of
"Software" supports a property called "studio" which is meant to hold the
name of the studio that produced the software. To output this property
you could use the following code:

    <mt:AmazonItemSearch asin="B00005JNOG">
    <img src="<$mt:AmazonItemProperty property="ImageUrlMedium"$>" /><br />
    <a href="<$mt:AmazonDetailPageURL$>"><$mt:AmazonTitle$></a> - 
    Studio: <$mt:AmazonItemProperty property="studio"$>
    </mt:AmazonItemSearch>

# Example Code

The following template tag sample code will show the last 4 Amazon 
items you added your system.

    <mt:Assets type="amazon" lastn="4">
    <mt:AssetsHeader>
    <div class="sidebar-module pkg" style="width: 185px; clear: right;">
      <h2 class="module-header">Currently</h2>
      <div class="module-content">
        <ul class="module-list"></mt:AssetsHeader>
          <li class="item" style="float:left">
            <a class="asset-image" href="<$mt:AssetURL$>">
              <div style="height: 75px; width: 75px; padding: 5px; background-repeat: no-repeat; background-position: center center; background-image: url(<$mt:AssetThumbnailURL width="75"$>)"></div></a>
          </li>
        <mt:AssetsFooter></ul>
      </div>
    </div>
    </mt:AssetsFooter>
    </mt:Assets>

See the documentation for the "Assets" tag for more information.

# Frequently Asked Questions

*Q: What is the difference between version 2.1 and 2.0?*

A: In 2009 Amazon made a significant change to their AWS Product Marketing
API on top of which Media Manager and MTAmazon are built. Media Manager 2.1
contains the fixes and changes necessary to make Media Manager work once again
with Amazon.

In updating the software to work with Amazon's new API, Media Manager was 
overhauled to utilize the CPAN module Net::Amazon. For most people this is
meaningless, so let me explain. Net::Amazon is a library, a small bit of 
software that talks to Amazon's APIs on behalf of Media Manager. The library
is maintained by a third party and far more flexible and performant than
anything that has previously shipped with Media Manager.

*Q: What are the changes between version 1.0 and 2.0?*

A: Media Manager 2.0 is a dramatic evolution from its predecessor. Media 
Manager now integrates far more seamlessly with Movable Type then ever
before. 

In this rearchitecture of the software, however, I redefined what the 
goals of the software are and adjusted the scope and feature set of the
product to meet those goals. For example, Media Manager 1.0 was an 
evolution of BookQueue and BookQueueToo, which by their name should
indicate that they presumed you were managing books alone. As a result
Media Manager 1.0 allowed users to set the "status" of an item as 
either "reading," "read" or "unread."

That is flawed assumption, especially in light of the fact that those
statii are irrelevant to CD's not to mention patio furniture - both
of which are available through Amazon. What follows is a list of
features that have been REMOVED:

* item statuses - users are encouraged to use Movable Type's built in
  tagging system to manage the state of an item
* reviews - now that Movable Type allows users to insert assets
  directly in their posts, there is no need to support the concept of 
  a "review." 
* ratings - ratings were associated with reviews in previous versions
  and since reviews are gone, so are ratings
* list import - i suspect many users did not make use of this feature
  so the ability to import items from an Amazon Wishlist has been 
  removed
* finished on date - yeah, sorry about this one for now

*Q: Is Media Manager 1.0 forward compatible with Media Manager 2.0?*

A: Items found in Media Manager 1.0 will automatically be ported into
the new Media Manager 2.0 and Movable Type 4.0 system. However, not
all data will be carried over. Reviews, ratings, and statii will NOT
be ported over. Not yet anyways.

*Q: Will my Media Manager 1.x template tags work with MT4 and MM2.0?*

A: No they will not. To simplify the code base and bring focus to
the Media Manager application, all legacy template tags have been 
removed. Movable Type's core template tag set should be sufficient 
for anything most users need to do.

# Resources

* [Melody](http://openmelody.org/)
* [MovableType](http://www.movabletype.org/)
* [Media Manager Homepage](http://www.majordojo.com/projects/mediamanager.php)
* [MTAmazon Homepage](http://www.majordojo.com/projects/mtamazon/)
* [Amazon Web Services](http://www.amazon.com/webservices/)
* [Net::Amazon](http://search.cpan.org/dist/Net-Amazon/)

# Bug Reports

You can file bug reports here:

* [Via the Web](http://majordojo.lighthouseapp.com/projects/36618-media-manager/tickets)
* [Via Email](mailto:ticket+majordojo.36618-k4kdjen6@lighthouseapp.com)

# Help and Donations

Media Manager represents a lot of work by one individual. While the author
is happy to write this software, and support it completely free of charge,
the author also appreciates and form of support you can provide. Please
consult the following URL to learn more:

  http://www.majordojo.com/projects/mediamanager.php

# Copyright

(c) 2007-2008 Six Apart, Ltd.
(c) 2009 Byrne Reese

# License

Media Manager is licensed under the Artistic License.

