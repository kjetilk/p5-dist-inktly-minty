use 5.010001;
use strict;
use warnings;

package Dist::Inktly::Minty;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '0.002';

use Carp;
use Path::Tiny 'path';
use Software::License;
use Text::Template;
use URI::Escape qw[];

{
	my %templates;
	my $key = undef;
	while (my $line = <DATA>)
	{
		if ($line =~ /^COMMENCE\s+(.+)\s*$/)
		{
			$key = $1;
		}
		elsif (defined $key)
		{
			$templates{$key} .= $line;
		}
	}
	sub _has_template
	{
		my $class = shift;
		my ($key) = @_;
		exists $templates{$key};
	}
	sub _get_template
	{
		my $class = shift;
		my ($key) = @_;
		'Text::Template'->new(-type=>'string', -source=>$templates{$key});
	}
	sub _get_template_names
	{
		my $class = shift;
		return keys %templates;
	}
}

sub _fill_in_template
{
	my $self = shift;
	my ($template) = @_;
	$template = $self->_get_template($template) unless ref $template;
	
	my %hash = ();
	while (my ($k, $v) = each %$self)
	{
		$hash{$k} = ref $v ? \$v : $v;
	}
	
	$template->fill_in(-hash => \%hash);
}

sub _file
{
	my $self = shift;
	my $file = path(
		$self->{destination},
		sprintf('p5-%s', lc($self->{dist_name}))
	)->child($_[0]);
	$file->parent->mkpath;
	return $file;
}

sub create
{
	my $class = shift;
	my ($name, %options) = @_;
	
	$options{module_name} = $name;
	$options{dist_name}   = $name;
	
	if ($name =~ /::/)
	{
		$options{dist_name} =~ s/::/-/g;
	}
	elsif ($name =~ /\-/)
	{
		$options{module_name} =~ s/\-/::/g;
	}
	
	my $self = bless \%options, $class;
	$self->set_defaults;
	$self->create_module;
	$self->create_dist_ini;
	$self->create_metadata;
	$self->create_tests;
	$self->create_author_tests;
	return $self;
}

sub set_defaults
{
	my $self = shift;
	
	croak "Need an author name."   unless defined $self->{author}{name};
	croak "Need an author cpanid." unless defined $self->{author}{cpanid};
	
	$self->{author}{cpanid} = lc $self->{author}{cpanid};
	$self->{author}{mbox} ||= sprintf('%s@cpan.org', $self->{author}{cpanid});

	$self->{backpan} ||= sprintf('http://backpan.cpan.org/authors/id/%s/%s/%s/',
		substr(uc $self->{author}{cpanid}, 0, 1),
		substr(uc $self->{author}{cpanid}, 0, 2),
		uc $self->{author}{cpanid},
	);
	
	$self->{abstract} ||= 'a module that does something-or-other';
	$self->{version}  ||= '0.001';
	$self->{version_ident} = 'v_'.$self->{version};
	$self->{version_ident} =~ s/\./-/g;
	$self->{destination} ||= './';
	
	unless ($self->{module_filename})
	{
		$self->{module_filename} = 'lib::'.$self->{module_name};
		$self->{module_filename} =~ s/::/\//g;
		$self->{module_filename} .= '.pm';
	}
	
	$self->{copyright}{holder} ||= $self->{author}{name};
	$self->{copyright}{year}   ||= 1900 + [localtime]->[5];
	
	$self->{licence_class} ||= 'Software::License::Perl_5';
	eval sprintf('use %s;', $self->{licence_class});
	$self->{licence} = $self->{licence_class}->new({
		year    => $self->{copyright}{year},
		holder  => $self->{copyright}{holder},
	});
}

sub create_module
{
	my $self = shift;
	$self->_file( $self->{module_filename} )->spew_utf8( $self->_fill_in_template('module') );
	return;
}

sub create_dist_ini
{
	my $self = shift;
	$self->_file('dist.ini')->spew_utf8($self->_fill_in_template('dist.ini'));
	return;
}

sub create_metadata
{
	my $self = shift;
	$self->_file($_)->spew_utf8($self->_fill_in_template($_))
		for grep { m#^meta/# } $self->_get_template_names;
	return;
}

sub create_tests
{
	my $self = shift;
	$self->_file($_)->spew_utf8($self->_fill_in_template($_))
		for grep { m#^t/# } $self->_get_template_names;
	return;
}

sub create_author_tests
{
	my $self = shift;
	
	$self->_file($_)->spew_utf8($self->_fill_in_template($_))
		for grep { m#^xt/# } $self->_get_template_names;
	
	my $xtdir = path("~/perl5/xt");
	return unless $xtdir->exists;

	$self->_file("xt/" . $_->relative($xtdir))->spew_utf8(scalar $_->slurp)
		for grep { $_ =~ /\.t$/ } $xtdir->children;
	
	return;
}

1;

=head1 NAME

Dist::Inktly::Minty - create distributions that will use Dist::Inkt

=head1 SYNOPSIS

  distinkt-mint Local::Example::Useful

=head1 STATUS

Experimental.

=head1 DESCRIPTION

This package provides just one (class) method:

=over

=item C<< Dist::Inktly::Minty->create($distname, %options) >>

Create a distribution directory including all needed files.

=back

There are various methods that may be useful for people subclassing this
class to look at (and possibly override).

=over

=item C<< set_defaults >>

=item C<< create_module >>

=item C<< create_dist_ini >>

=item C<< create_metadata >>

=item C<< create_tests >>

=item C<< create_author_tests >>

=back

=head1 SEE ALSO

L<Dist::Inkt>.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2013 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 DISCLAIMER OF WARRANTIES

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.

=cut

__DATA__

COMMENCE module
use 5.010001;
use strict;
use warnings;

package {$module_name};

our $AUTHORITY = 'cpan:{uc $author->{cpanid}}';
our $VERSION   = '{$version}';

1;

{}__END__

{}=pod

{}=encoding utf-8

{}=head1 NAME

{$module_name} - {$abstract}

{}=head1 SYNOPSIS

{}=head1 DESCRIPTION

{}=head1 BUGS

Please report any bugs to
L<https://github.com/{lc $author->{cpanid}}/p5-{lc URI::Escape::uri_escape($dist_name)}/issues>.

{}=head1 SEE ALSO

{}=head1 AUTHOR

{$author->{name}} E<lt>{$author->{mbox}}E<gt>.

{}=head1 COPYRIGHT AND LICENCE

{$licence->notice}

{}=head1 DISCLAIMER OF WARRANTIES

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.

COMMENCE dist.ini
;;class='Dist::Inkt::Profile::TOBYINK'
;;name='{$dist_name}'

COMMENCE meta/changes.pret
# This file acts as the project's changelog.

`{$dist_name} {$version} cpan:{uc $author->{cpanid}}`
	issued  {sprintf('%04d-%02d-%02d', 1900+(localtime)[5], 1+(localtime)[4], (localtime)[3])};
	label   "Initial release".

COMMENCE meta/doap.pret
# This file contains general metadata about the project.

@prefix : <http://usefulinc.com/ns/doap#>.
@prefix dc:   <http://purl.org/dc/terms/> .
@prefix prov: <http://www.w3.org/ns/prov#>.

`{$dist_name}`
   :programming-language "Perl" ;
   :shortdesc            "{$abstract}";
   :homepage             <https://metacpan.org/release/{URI::Escape::uri_escape($dist_name)}>;
   :download-page        <https://metacpan.org/release/{URI::Escape::uri_escape($dist_name)}>;
   :bug-database         <https://github.com/{lc $author->{cpanid}}/p5-{lc URI::Escape::uri_escape($dist_name)}/issues>;
   :repository           [ a :GitRepository;
                           :browse <https://github.com/{lc $author->{cpanid}}/p5-{lc URI::Escape::uri_escape($dist_name)}>;
                           prov:has_provenance <http://git2prov.org/git2prov?giturl=https%3A%2F%2Fgithub.com%2F{lc $author->{cpanid}}%2Fp5-{lc URI::Escape::uri_escape($dist_name)}&serialization=PROV-O#>
                         ];
#   :support-forum        <irc://irc.perl.org/#perlrdf> ;
   :created              {sprintf('%04d-%02d-%02d', 1900+(localtime)[5], 1+(localtime)[4], (localtime)[3])};
   :license              <{$licence->url}>;
   :maintainer           cpan:{uc $author->{cpanid}};
   :security-contact     cpan:{uc $author->{cpanid}};
   :developer            cpan:{uc $author->{cpanid}}.


COMMENCE meta/people.pret
# This file contains data about the project developers.

@prefix : <http://xmlns.com/foaf/0.1/>.
@prefix owl:  <http://www.w3.org/2002/07/owl#> .
@prefix result: <http://git2prov.org/git2prov?giturl=https%3A%2F%2Fgithub.com%2F{lc $author->{cpanid}}%2Fp5-{lc URI::Escape::uri_escape($dist_name)}&serialization=PROV-O#> .

cpan:{uc $author->{cpanid}}
  :name  "{$author->{name}}";
  owl:sameAs result:user-{$author->{name}}.

COMMENCE meta/makefile.pret
# This file provides instructions for packaging.

@prefix : <http://ontologi.es/doap-deps#>.

`{$dist_name}`
	:test-requirement       [ :on "Test::More 0.96"^^:CpanId ];
	:develop-recommendation [ :on "Dist::Inkt 0.001"^^:CpanId ];
	.

COMMENCE t/01basic.t
{}=pod

{}=encoding utf-8

{}=head1 PURPOSE

Test that {$module_name} compiles.

{}=head1 AUTHOR

{$author->{name}} E<lt>{$author->{mbox}}E<gt>.

{}=head1 COPYRIGHT AND LICENCE

{$licence->notice}

{}=cut

use strict;
use warnings;
use Test::More;

use_ok('{$module_name}');

diag( "Testing {$module_name} ${$module_name}::VERSION, Perl $], $^X" );

done_testing;

COMMENCE xt/03meta_uptodate.config
\{"package":"{$dist_name}"\}

