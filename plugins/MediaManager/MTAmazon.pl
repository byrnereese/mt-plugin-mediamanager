#!/usr/bin/perl -w

# Description: MTAmazon is a plugin designed for the Movable Type Publishing
#              Platform. It enables users to query and display items from
#              Amazon's product catalog within their published blog using
#              a few simple template tags.
#
# The copyright of this software is jointly owned between the following
#   parties:
# Copyright 2006 Byrne Reese
#
# $Id: $

package MT::Plugin::MTAmazon;

use MT;

use strict;
use base qw( MT::Plugin );
use constant DEBUG => 0;
our $VERSION = '4.0';

my $plugin = MT::Plugin::MTAmazon->new({
    id              => 'MTAmazon',
    key             => 'MTAmazon',
    name            => 'MTAmazon',
    version         => $VERSION,
    author_name     => "Byrne Reese",
    author_link     => "http://www.majordojo.com/",
    description     => "MTAmazon is a Movable Type plugin that uses your Amazon Associate membership to retrieve products from Amazon. It allows flexible searching and display of products from any of Amazon's product categories.",
    doc_link        => "http://www.majordojo.com/projects/MTAmazon/docs.php",
    system_config_template => \&sysconf_template,
    blog_config_template => \&blogconf_template,
    schema_version => 1,
    settings        => new MT::PluginSettings([
					       ['accesskey',   { Default => '', 
								 Scope => 'blog' }],
					       ['secretkey',   { Default => '', 
								 Scope => 'blog' }],
					       ['associateid', { Default => 'majordojo-20', 
								 Scope => 'blog' }],
					       ['locale',      { Default => 'us',
								 Scope => 'blog' }],
					       ['delay',       { Default => 0,
								 Scope => 'blog' }],
					       
					       ['cache_path',   { Default => '' }],
					       ['cache_expire', { Default => '' }],

					       ['accesskey',    { Default => '' }],
					       ['secretkey',    { Default => '' }],
					       ['associateid',  { Default => 'majordojo-20' }], 
					       ['allow_aid',    { Default => 1 }],
					       ['allow_sid',    { Default => 1 }],
					       ]),
    });

sub instance { $plugin; }

MT->add_plugin($plugin);

sub init_registry {
    my $plugin = shift;
    $plugin->registry({
        tags => {
            block => {
                'AmazonItemSearch' => '$MediaManager::Amazon::Plugin::ItemSearch',
            },
            function => {
                'AmazonASIN' => '$MediaManager::Amazon::Plugin::AmazonASIN',
                'AmazonTitle' => '$MediaManager::Amazon::Plugin::AmazonTitle',
                'AmazonDetailPageURL' => '$MediaManager::Amazon::Plugin::AmazonDetailPageURL',
                'AmazonProductGroup' => '$MediaManager::Amazon::Plugin::AmazonProductGroup',
                'AmazonImageTag' => '$MediaManager::Amazon::Plugin::AmazonImageTag',
                'AmazonImageURL' => '$MediaManager::Amazon::Plugin::AmazonImageURL',
                'AmazonPrice' => '$MediaManager::Amazon::Plugin::AmazonPrice',
                'AmazonItemProperty' => '$MediaManager::Amazon::Plugin::AmazonItemProperty',
            },
        },
        object_types => {
            'asset.amazon' => 'MT::Asset::Amazon',
        },
        applications => {
            cms => {
                methods => {
                    clear_cache => '$MediaManager::Amazon::CMS::clear_cache',
                },
            },
        },
   });
}

sub blogconf_template {
    my ($plugin,$param,$scope) = @_;
    require Amazon::Util;
    my $cfg = Amazon::Util::readconfig(MT::App->instance->blog->id,
					  { ignore_errors => 1} );
    my $tmpl = "";
    if ($cfg->{allow_sid}) {
	$tmpl .= <<'EOT';
    <div class="setting">
      <div class="label">
        <label for="accesskey">Access Key:</label>
      </div>
      <div class="field">
        <p><input type="text" size="30" name="accesskey" value="<TMPL_VAR NAME=ACCESSKEY>" /><br />
        <a target="_new" href="http://www.amazon.com/gp/aws/registration/registration-form.html">Register for an Access Key</a> | 
        <a target="_new" href="http://docs.amazonwebservices.com/AWSECommerceService/2007-10-29/GSG/GettinganAWSAccessKeyID.html">What is an Access Key?</a></p>
      </div>
    </div>
    <div class="setting">
      <div class="label">
        <label for="accesskey">Secret Key:</label>
      </div>
      <div class="field">
        <p><input type="text" size="30" name="secretkey" value="<TMPL_VAR NAME=SECRETKEY>" /></p>
      </div>
    </div>
EOT
    }
    if ($cfg->{allow_aid}) {
        $tmpl .= <<'EOT';
    <div class="setting">
      <div class="label">
        <label for="associateid">Associates Id:</label>
      </div>
      <div class="field">
        <p><input type="text" size="30" name="associateid" value="<TMPL_VAR NAME=ASSOCIATEID>" /></p>
      </div>
    </div>
EOT
    }
    $tmpl .= <<'EOT';
    <div class="setting">
      <div class="label">
        <label for="locale">Locale:</label>
      </div>
      <div class="field">
        <select name="locale">
EOT
    my %locales = ( 'us' => "United States",
		    'uk' => "United Kingdom",
		    'de' => "Germany",
		    'jp' => "Japan",
		    'fr' => "France",
		    'ca' => "Canada",
		    );
    foreach my $l (sort keys %locales) {
	$tmpl .= "<option value=\"$l\"".($l eq $param->{'locale'} ? " selected" : "").">".$locales{$l}."</option>\n";
    }
     $tmpl .= <<EOT;
        </select>
      </div>
    </div> 
    <div class="setting">
      <div class="label">
      </div>
      <div class="field">
        <p><strong>Insert a 1 second delay between Amazon inquires?<sup>*</sup></strong></p>
        <p>
EOT
    $tmpl .= '<input type="radio" id="delay_yes" name="delay" value="1" '.($cfg->{delay} ? "checked " : "").'/> <label for="delay_yes">Yes</label>';
    $tmpl .= '&nbsp;&nbsp;';
    $tmpl .= '<input type="radio" id="delay_no" name="delay" value="0" '.(!$cfg->{delay} ? "checked " : "").'/> <label for="delay_no">No</label>';
	  $tmpl .= <<EOT;
        </p>
        <p style="font-size: 80%"><sup>*</sup> Amazon will often rate limit the number of requests a given subscriber ID is allowed to make if that ID makes more than one request per second. Inserting a delay will alleviate this problem. Only set this to 'Yes' if you are receiving error messages from Amazon, or your rebuilds will get very slow.</p>
      </div>
    </div>
EOT
}

sub sysconf_template {
    my $tmpl = <<'EOT';
<script type="text/javascript">
function getHTTPObject() {
  var xmlhttp;
  /*@cc_on
  @if (@_jscript_version >= 5)
  try {
    xmlhttp = new ActiveXObject("Msxml2.XMLHTTP");
  } catch (e) {
    try {
      xmlhttp = new ActiveXObject("Microsoft.XMLHTTP");
    } catch (E) {
      xmlhttp = false;
    }
  }
  @else
  xmlhttp = false;
  @end @*/
  if (!xmlhttp && typeof XMLHttpRequest != 'undefined') {
    try {
      xmlhttp = new XMLHttpRequest();
    } catch (e) {
      xmlhttp = false;
    }
  }
  return xmlhttp;
}
var clients = Array();
function clear_cache( bttn ) {
  var id = 'foo';
  clients[id] = getHTTPObject(); // We create the HTTP Object
  var url = '?__mode=clear_cache';
  clients[id].open("GET", url, true); 
  clients[id].onreadystatechange = function() {
    if (clients[id].readyState == 1) {  
      getByID('clear-cache').innerHTML = '<img src="' + StaticURI + 'plugins/MediaManager/images/indicator.gif" />'; 
    } else if (clients[id].readyState == 4) {  
      var txt = clients[id].responseText;
      getByID('clear-cache').innerHTML = txt;
      clients[id] = 0;
    }
  }; 
  clients[id].send(null);
}
</script>

    <div class="setting">
      <div class="label">
        <label for="accesskey">Access Key:</label>
      </div>
      <div class="field">
        <p><input type="text" size="30" name="accesskey" value="<TMPL_VAR NAME=ACCESSKEY>" /><br />
        <a target="_new" href="http://www.amazon.com/gp/aws/registration/registration-form.html">Register for an Access Key</a> | 
        <a target="_new" href="http://docs.amazonwebservices.com/AWSECommerceService/2007-10-29/GSG/GettinganAWSAccessKeyID.html">What is an Access Key?</a></p>
      </div>
      <div class="label">
        <label for="accesskey">Secret Key:</label>
      </div>
      <div class="field">
        <p><input type="text" size="30" name="secretkey" value="<TMPL_VAR NAME=SECRETKEY>" /></p>
      </div>
      <div class="label"></div>
      <div class="field">
        <p><input type="checkbox" name="allow_sid" value="1" <TMPL_IF NAME=ALLOW_SID>checked </TMPL_IF>/> Permit blog owners to use their own Amazon Access and Secret Keys.</p>
      </div>
    </div>
    <div class="setting">
      <div class="label">
        <label for="devtoken">Associates Id:</label>
      </div>
      <div class="field">
        <p><input type="text" size="30" name="associateid" value="<TMPL_VAR NAME=ASSOCIATEID>" /></p>
      </div>
      <div class="label"></div>
      <div class="field">
        <p><input type="checkbox" name="allow_aid" value="1" <TMPL_IF NAME=ALLOW_AID>checked </TMPL_IF>/> Permit blog owners to use their own Amazon Associates ID.</p>
      </div>
    </div>

    <div class="setting">
      <div class="label">
        <label for="accesskey">Cache Path:</label>
      </div>
      <div class="field">
        <input type="text" size="30" name="cache_path" value="<TMPL_VAR NAME=CACHE_PATH>" />
      </div>
      <div class="label">
        <label for="accesskey">Cache Expires:</label>
      </div>
      <div class="field">
        <p><input type="text" size="30" name="cache_expire" value="<TMPL_VAR NAME=CACHE_EXPIRE>" /></p>
      </div>
    </div>
    <div class="setting">
      <div class="label"></div>
      <div class="field">
        <p id="clear-cache">
          <input type="button" value="Clear Cache" onclick="clear_cache()" />
        </p>
      </div>
    </div> 
EOT
}

1;
__END__

