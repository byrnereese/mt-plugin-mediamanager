use ExtUtils::MakeMaker;

my $file = "plugins/MediaManager/MediaManager.pl";
my $version;
open FILE,$file;
while (<FILE>) {
    last if ($version) = ($_ =~ /\$VERSION = '([^\']*)'/);
}
close FILE;

WriteMakefile(
    NAME            => 'Media Manager',
    VERSION         => $version,
    DISTNAME        => 'MediaManager',
);
