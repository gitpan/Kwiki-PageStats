package Kwiki::PageStats;
use Kwiki::Plugin '-Base';
use Kwiki::Installer '-base';

const class_id             => 'page_stats';
const class_title          => 'PageStats';
const lock_count           => 10;

field count => 0;
field 'mtime';

our $VERSION = '0.01';

sub storage_directory {
    $self->plugin_directory;
}

sub register {
    my $registry = shift;
    $registry->add(status => 'page_stats',
                   template => 'page_stats.html',
                   show_for => 'display',
                  );
    $registry->add(preference => $self->show_page_stats);
}

sub show_page_stats {
    my $p = $self->new_preference('show_page_stats');
    $p->query('Show hits in status bar?');
    $p->type('boolean');
    $p->default(1);
    return $p;
}

sub increment_page_count {
    my $file = io($self->data_file)->file;
    my $previous = 0;
    my $mtime;
    if ($file->exists) {
        $previous = $file->all;
        $mtime = $file->mtime;
    }
    $file->close;
    $previous++;
    $self->count($previous);
    $self->mtime($mtime) if $mtime;
}

sub write_page_count {
    my $file = io($self->data_file)->file;
    $file->print($self->count);
    $file->close;
}

sub touch_ctime {
    my $file = io($self->ctime_file);
    $file->touch unless $file->exists;
}

sub file_ctime {
    my $time = io($self->ctime_file)->file->ctime;
    return scalar gmtime($time);
}

sub page_stats {
    return unless $self->preferences->show_page_stats->value;
    eval {$self->lock;};
    return 'X' if $@;
    $self->increment_page_count;
    $self->write_page_count;
    $self->touch_ctime;
    $self->unlock;
    return {
        count => $self->count,
        ctime => $self->file_ctime,
        $self->mtime ? (mtime => scalar gmtime($self->mtime)) : ()
    };
}

sub ctime_file {
    $self->data_file . '.time';
}

sub data_file {
    my $id = $self->hub->pages->current->id;
    $self->storage_directory . '/' . $id;
}

sub lock_directory {
    $self->data_file . '.lck';
}

# taken from PurpleWiki and Kwiki-Purple
sub lock {
    my $tries = 0;
    while (!mkdir($self->lock_directory, 0555)) {
        die "unable to create page counting lock directory"
          if ($! != 17);
        $tries++;
        die "timeout attempting to lock page count"
          if ($tries > $self->lock_count);
        sleep 1;
    }
}

sub unlock {
    rmdir($self->lock_directory) or
      die "unable to page count locking directory";
}

__DATA__

=head1 NAME

Kwiki::PageStats - Count and show page hits with a hook.

=head1 DESCRIPTION

Kwiki::PageStats shows a count of how many times a page has been 
viewed.

=head1 AUTHORS

Chris Dent, <cdent@burningchrome.com>

=head1 SEE ALSO

L<Kwiki>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005, Chris Dent

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
__template/tt2/page_stats.html__
<!-- BEGIN page_stats -->
[% page_info = hub.page_stats.page_stats %]
[% IF page_info.count %]
<div style="font-family:Helvetica,Arial,sans-serif; font-size:small;"
     id="page_stats">
[% page_info.count %] hit(s) since [% page_info.ctime %].
[% IF page_info.mtime %]
Last hit at [% page_info.mtime %]
[% END %]
</div>
[% END %]
<!-- END page_stats -->
