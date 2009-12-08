#
# Media Manager 2.0 - A plugin for Movable Type
# 

OVERVIEW

Media Manager provides users and authors within Movable Type the ability
to manage books, CDs, DVDs, or any item found in Amazon's product catalog
alongside all their other image, video and audio media.

In other words, Media Manager defines an "Amazon" asset type that plugs
seamlessly into Movable Type's Asset Management system.

PREREQUISITES

Media Manager 2.0 requires Movable Type 4.01 or greater.

INSTALLATION AND UPGRADING

Please see INSTALL.txt.

FREQUENTLY ASKED QUESTIONS

Q: What are the changes between version 1.0 and 2.0?

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

Q: Is Media Manager 1.0 forward compatible with Media Manager 2.0?

A: Items found in Media Manager 1.0 will automatically be ported into
the new Media Manager 2.0 and Movable Type 4.0 system. However, not
all data will be carried over. Reviews, ratings, and statii will NOT
be ported over. Not yet anyways.

Q: Will my Media Manager 1.x template tags work with MT4 and MM2.0?

A: No they will not. To simplify the code base and bring focus to
the Media Manager application, all legacy template tags have been 
removed. Movable Type's core template tag set should be sufficient 
for anything most users need to do.

KNOWN ISSUES

Movable Type 4.0 does not have a way to edit assets yet. Therefore
once an item has been added, it cannot be edited except by deleting
it and re-adding it.

ACCESSING THE INTERFACE

To add an item from Amazon to your list of Assets, select "Amazon
Item" from the Create menu and follow the instructions. Adding an 
item from Amazon to a post is done exactly like inserting any other
asset.

TEMPLATE TAGS

Media Manager 2.0 does not yet expose any template tags of its own.
It relies upon Movable Type 4.0's template tags entirely.

EXAMPLES

The following template tag sample code will show the last 4 Amazon 
items you added your system.

    <MTAssets type="amazon" lastn="4">
    <MTAssetsHeader>
    <div class="sidebar-module pkg" style="width: 185px; clear: right;">
      <h2 class="module-header">Currently</h2>
      <div class="module-content">
        <ul class="module-list"></MTAssetsHeader>
          <li class="item" style="float:left">
            <a class="asset-image" href="<$MTAssetURL$>"><div style="height: 75px; width: 75px; padding: 5px; background-repeat: no-repeat; background-position: center center; background-image: url(<$MTAssetThumbnailURL width="75"$>)"></div></a>
          </li>
        <MTAssetsFooter></ul>
      </div>
    </div>
    </MTAssetsFooter>
    </MTAssets>

See the documentation for the "Assets" tag for more information.

OTHER LINKS AND RESOURCES

  Media Manager homepage and blog:
  http://www.majordojo.com/projects/mediamanager.php

  MTAmazone32 homepage and blog:
  http://www.majordojo.com/projects/mtamazon/

  Amazon Web Services
  http://www.amazon.com/webservices/

  MovableType:
  http://www.movabletype.org/

  Other MT plugins:
  http://plugins.movabletype.org/

SUPPORT

Please post your bugs, questions and comments to the Media Manager project
homepage:

  http://www.majordojo.com/projects/mediamanager.php

HELP AND DONATIONS

Media Manager represents a lot of work by one individual. While the author
is happy to write this software, and support it completely free of charge,
the author also appreciates and form of support you can provide. Please
consult the following URL to learn more:

  http://www.majordojo.com/projects/mediamanager.php

LICENSE

Media Manager is licensed under the Artistic License.

COPYRIGHT

This plugin has been donated to the Movable Type Open Source Project.
Copyright 2007, Six Apart, Ltd.

MTAmazon, bundled with Media Manager is licensed separately under the GPL
and Copyrighted by Byrne Reese and Adam Kalsey.