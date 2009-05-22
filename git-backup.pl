#!/usr/bin/perl

use MooseX::Declare;

class GitBackup {

  # Constructor's named parameters
  has log => (isa => 'Str', is => 'rw');
  has working_copy => (isa => 'Str', is => 'rw', required => 1);
  has folders => (isa => 'HashRef', is => 'ro', required => 1);
  has db_username => (isa => 'Str', is => 'ro', required => 1);
  has db_password => (isa => 'Str', is => 'ro', required => 1);
  has mail_dear => (isa => 'Str', is => 'ro', default => "Sir or Madam");
  has mail_signed => (isa => 'Str', is => 'ro', default => "git-backup.pl");
  has mail_to => (isa => 'Str', is => 'ro', required => 1);
  has mail_from => (isa => 'Str', is => 'ro', required => 1);
  has mail_backed_up_host => (isa => 'Str', is => 'ro', required => 1);

  # Other attributes
  has date => (isa => 'Str', is => 'rw');

  method run {
    $self->date(scalar localtime);
    chdir $self->working_copy or
      die "Can't change into directory '", $self->working_copy, "'.";
    $self->delete_working_copy_files;
    $self->copy_files_to_working_copy;
    $self->mysqldump;
    $self->mark_deletes;
    $self->mark_new_files;
    $self->commit_all_changes;
    $self->push_backup;
    $self->mail_push_notice;
  }

  method delete_working_copy_files {
    for my $folder (keys %{$self->folders}) {`rm -Rf $folder`}
  }

  method copy_files_to_working_copy {
    my ($source, $target, $folder, $subfolder, $find);
    for $folder (keys %{$self->folders}) {
      `/bin/rm -Rf $folder`;
      `/bin/mkdir $folder`;
      for $subfolder
        (ref($self->folders->{$folder}) ?
         @{$self->folders->{$folder}} : $self->folders->{$folder})
        {`/bin/cp -RL --no-preserve=mode,ownership $subfolder $folder`}
      $find= "/usr/bin/find $folder";
      `$find -type f -executable -exec /bin/chmod 755 "{}" \\;`;
      `$find -type f ! -executable -exec /bin/chmod 644 "{}" \\;`;
      `$find -type d -exec /bin/chmod 755 "{}" \\;`;
    }
  }

  method mysqldump {
    my $credentials= "-u " . $self->db_username .
      " --password=" . $self->db_password;
    my $options= "-A --create-options";
    `/usr/bin/mysqldump $credentials $options >mysql-backup.sql`;
  }

  method mark_deletes {
    for my $file ($self->deleted_files) {`git rm $file`}}

  method deleted_files {
    grep {$_ ne ''}
      map {/^#\s+deleted:\s+([^ ]+)$/; $_= $1; s/^\s+|\s+$//sg; $_}
        grep {/^#\s+deleted:\s+/sg}
          `/usr/bin/git status`}

  method mark_new_files {`/usr/bin/git add .`}

  method commit_all_changes {
    my $date= $self->date;
    `/usr/bin/git commit -a -m "Commiting sinistercode backup for $date"`}

  method push_backup {`git push`}

  method mail_push_notice {
    open(MAIL, '| /usr/lib/sendmail -t -oi') or die "Can't send mail.";
    print MAIL
      "To: ", $self->mail_to, "\n",
      "From: ", $self->mail_from, "\n",
      "Subject: Updated sinistercode backup repository\n\n",
      "Dear ", $self->mail_dear, ",\n\n",
      "I have updated the backup repository with the latest changes in ",
      $self->mail_backed_up_host, "\n\n",
      "--", $self->mail_signed;
    close MAIL;
  }
}

GitBackup->new(
  log => '/home/webmaster/log/webapps-backup.log',
  working_copy => '/backup/sinistercode-webapps',
  folders => +{
    # New home for folders and files      Folders and files to back up
    'drupal-sites' =>                     '/www/drupal/sites/*',
    'wordpress-sites' =>                  '/www/cjanerock.com/*',
  },
  db_username => 'root',
  db_password => 'xxxxxxxxxxxx',
  mail_dear => 'Donnie',
  mail_signed => 'donnieknows.com',
  mail_to => 'donnie@solomonstreet.com',
  mail_from => 'donnieknows.com <no-reply@donnieknows.com>',
  mail_backed_up_host => 'donnieknows.com'
)->run;
