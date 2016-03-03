# See bottom of file for default license and copyright information

package Foswiki::Plugins::RecordChangesPlugin;

use strict;
use warnings;
#use Carp::Always;

use Foswiki::Func    ();    # The plugins API
use Foswiki::Plugins ();    # For the API version

our $VERSION = '1.0';
our $RELEASE = '1.0';

our $SHORTDESCRIPTION = 'Record who made content changes.';

our $NO_PREFS_IN_TOPIC = 1;

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    # Plugin correctly initialized
    return 1;
}

sub beforeSaveHandler {
    my ($text, $topic, $web, $meta) = @_;

    my $oldMeta;
    if(Foswiki::Func::topicExists($web, $topic)) {
        ($oldMeta, undef) = Foswiki::Func::readTopic($web, $topic);
    } else {
        # empty meta, so everything will be recorded as changed
        $oldMeta = new Foswiki::Meta($meta);
    }

    my $changes = checkChanges($oldMeta, $meta);
    _putChanges($changes, $meta);
}

sub _hashesDiffer {
    my ($a, $b) = @_;

    return 1 if scalar keys %$a != scalar keys %$b;
    foreach my $key ( keys %$a ) {
        return 1 unless defined $b->{$key} && $a->{$key} eq $b->{$key};
    }

    return 0;
}

sub _putChanges {
    my ( $changes, $meta ) = @_;

    if($changes) {
        my $metaChanges = $meta->get('CHANGES');
        $metaChanges = { name => 'changes' } unless $metaChanges;

        my $combined = { %$metaChanges, %$changes };

        if(_hashesDiffer($metaChanges, $combined)) {
            $meta->remove('CHANGES');
            $meta->put('CHANGES', $combined );

            return 1;
        }
    }
    return 0;
}

sub historyCatchup {
    my ( $includeweb, $excludeweb, $includetopic, $excludetopic ) = @_;

    $includeweb = '.*' unless defined $includeweb;
    $excludeweb = '^(?:System|Trash)\b' unless defined $excludeweb;
    $includetopic = '.*' unless defined $includetopic;
    $excludetopic = '^Web' unless defined $excludetopic;

    foreach my $web ( Foswiki::Func::getListOfWebs() ) {
        next unless $web =~ m#$includeweb#;
        next if $web =~ m#$excludeweb#;

        foreach my $topic ( Foswiki::Func::getTopicList($web) ) {
            next unless $topic =~ m#$includetopic#;
            next if $topic =~ m#$excludetopic#;

            my $changes = {};
            my ($meta, undef) = Foswiki::Func::readTopic($web, $topic);

            my $oldMeta = new Foswiki::Meta($meta);
            my ( undef, undef, $maxrev ) = $meta->getRevisionInfo();
            for ( my $rev = 1; $rev <= $maxrev; $rev++) {
                my ($newMeta, undef) = Foswiki::Func::readTopic($web, $topic, $rev);
                my $thischanges = checkChanges($oldMeta, $newMeta);
                $changes = { %$changes, %$thischanges } if $thischanges;
                $oldMeta = $newMeta;
            }

            if(_putChanges($changes, $meta)) {
                print STDOUT "Recording changes in $web.$topic\n";
                Foswiki::Func::saveTopic($web, $topic, $meta, undef, { dontlog => 1, minor => 1, forcenewrevision => 1 });
            }
        }
    }
}

sub checkChanges {
    my ($newMeta, $oldMeta) = @_;

    my $changes = {};

    my $plaintext = $newMeta->text();
    $plaintext =~ s#^\s+##;
    $plaintext =~ s#\s+$##;

    my $oldPlaintext = $oldMeta->text();
    $oldPlaintext =~ s#^\s+##;
    $oldPlaintext =~ s#\s+$##;
    if($oldPlaintext ne $plaintext) {
        $changes->{text} = 1;
    }

    my %seen = ();
    foreach my $pref ( $newMeta->find('FIELD') ) {
        my $name = $pref->{name};
        $seen{$name} = 1;

        my $oldPref = $oldMeta->get('FIELD', $name);
        if(!$oldPref || $oldPref->{value} ne $pref->{value}) {
            $changes->{$name} = 1;
        }
    }
    foreach my $pref ( $oldMeta->find('FIELD') ) {
        my $name = $pref->{name};
        next if $seen{$name};
        $seen{$name} = 1;

        $changes->{$name} = 1;
    }

    if(scalar keys %$changes) {
        my ($date, $author) = $newMeta->getRevisionInfo();
        my $prefix = $Foswiki::cfg{Extensions}{RecordChangesPlugin}{prefix};
        $prefix = Foswiki::Func::expandCommonVariables($prefix, $newMeta->topic(), $newMeta->web(), $newMeta) if defined $prefix;
        $prefix = undef unless defined $prefix && $prefix ne '';

        my $formattedChanges = {};
        foreach my $change ( keys %$changes ) {
            $formattedChanges->{"${change}_author"} = $author;
            $formattedChanges->{"${change}_dt"} = $date;
            if(defined $prefix) {
                $formattedChanges->{"${prefix}_${change}_author"} = $author;
                $formattedChanges->{"${prefix}_${change}_dt"} = $date;
            }
        }

        return $formattedChanges;
    }

    return undef
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2014 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
