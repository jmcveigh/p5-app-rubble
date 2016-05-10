#!/bin/perl

use strict;
use warnings;

package RubbleApp {
    use Moose;

    use Image::Magick;
    use YAML::Tiny;
    
    use feature 'say';
    use feature 'state';
    
    use namespace::autoclean;

    use Fcntl;
    
    has '_resolutions' => (
        is => 'ro',
        isa => 'HashRef',
        default => sub {
            return({
                hd => '1920x1080',
                cinematic => '4096x2160',    
            });
        },
        required => 1,
    );

    has '_output' => (
        is => 'ro',
        isa => 'Image::Magick',
        default => sub { new Image::Magick },
        required => 1,
    );
    
    has '_bg' => (
        is => 'ro',
        isa => 'Image::Magick',
        default => sub { new Image::Magick },
        required => 1,
    );
    
    has '_art' => (
        is => 'ro',
        isa => 'Image::Magick',
        default => sub { new Image::Magick },
        required => 1,
    );
    
    has '_config' => (
        is => 'ro',
        isa => 'HashRef',
        builder => '_build_config',
        required => 1,
    );
    
    sub _build_config {
        if (-r $ARGV[0]) {
            return((YAML::Tiny->read($ARGV[0]))->[-1]);
        }
        
        return(undef);
    }
    
    sub read_common_elements {
        my $self = shift;
        
        if (-r $self->_config->{input}->{path} . $self->_config->{elements}->{bg} && -r $self->_config->{input}->{path} . $self->_config->{elements}->{art}) {
            $self->_bg->Read($self->_config->{input}->{path} . $self->_config->{elements}->{bg});
            $self->_art->Read($self->_config->{input}->{path} . $self->_config->{elements}->{art});
            die "element read error" unless $self->_bg;
        } else {
            die "element files not found or not readable (bg, art)";
        }
    }
    
    sub bg_fx {
        my $self = shift;
        $self->_bg->Blur($self->_config->{elements}->{blur}) if ($self->_config->{elements}->{blur});        
    }
    
    sub compose_of_common_elements {
        my $self = shift;
        
        $self->_output->Composite(image => $self->_bg,gravity=>"NorthWest", x => 0, y => 0);
		
	# drop shadow, black
	$self->_art->Set(background => 'black');
	my $shadow = $self->_art->Clone();
	$shadow->Shadow(geometry => '500x8', x => '+8', y => '+8');
		
	$self->_output->Composite(image => $shadow,gravity=>"NorthWest", x => 117, y => 392);
        $self->_output->Composite(image => $self->_art,gravity=>"NorthWest", x => 117, y => 392);        
    }
    
    sub main {
        my ($self) = shift;
        
        my $fps = 60;
        
        die "configuration error" unless $self->_config;
        
        $self->_output->Set(size => $self->_resolutions->{$self->_config->{output}->{resolution}});
        $self->_output->Read('xc:black');
                
        $self->read_common_elements;
        
        $self->bg_fx;
        
        $self->compose_of_common_elements;
        
        my $still_filename = $self->_config->{output}->{path} . $self->_config->{output}->{still};
        
        $self->_output->Write($still_filename);
        
        my $audio_filename = $self->_config->{input}->{path} . $self->_config->{elements}->{music};
        
        my $video_filename = $self->_config->{output}->{path} . $self->_config->{output}->{video};
                
        `ffmpeg -y -loop 1 -framerate 2 -i $still_filename -i $audio_filename  -c:v libx264 -preset medium -tune stillimage -crf 18 -c:a copy -shortest -pix_fmt yuv420p $video_filename`;
    }

    __PACKAGE__->meta->make_immutable;
}

my $app = RubbleApp->new->main unless caller;

1;