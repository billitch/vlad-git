class Vlad::Git

  # Duh.
  VERSION = "2.2.0"

  set :source,  Vlad::Git.new
  set :git_cmd, "git"
  set :git_subdir, ""

  # Returns the command that will check out +revision+ from the
  # repository into directory +destination+.  +revision+ can be any
  # SHA1 or equivalent (e.g. branch, tag, etc...)

  def checkout(revision, destination)
    destination = File.join(destination, 'repo')
    revision = 'HEAD' if revision =~ /head/i
    new_revision = ('HEAD' == revision) ? "origin" : revision

    if fast_checkout_applicable?(revision, destination)
      [ "cd #{destination}",
        "#{git_cmd} checkout -q origin",
        "#{git_cmd} fetch",
        "#{git_cmd} reset --hard #{new_revision}",
        submodule_cmd,
        "#{git_cmd} branch -f deployed-#{revision} #{revision}",
        "#{git_cmd} checkout deployed-#{revision}",
        "cd -"
      ].join(" && ")
    else
      [ "rm -rf #{destination}",
        "#{git_cmd} clone #{repository} #{destination}",
        "cd #{destination}",
        "#{git_cmd} checkout -f -b deployed-#{revision} #{revision}",
        submodule_cmd,
        "cd -"
      ].join(" && ")
    end
  end

  # Returns the command that will export +revision+ from the current
  # directory into the directory +destination+. Expects to be run
  # from +scm_path+ after Vlad::Git#checkout.

  def export(revision, destination)
    revision = 'HEAD' if revision =~ /head/i
    revision = "deployed-#{revision}"
    subdir = git_subdir or ""
    subdir = "/#{git_subdir}" unless subdir == "" or subdir.starts_with('/')

    [ "vlad_git_export_tmp=$(mktemp -d #{destination}.tmp_XX)",
      "cd repo",
      "#{git_cmd} archive --format=tar #{revision} | (cd $vlad_git_export_tmp && tar xf -)",
      "#{git_cmd} submodule foreach '#{git_cmd} archive --format=tar $sha1 | (cd ${vlad_git_export_tmp}/$path && tar xf -)'",
      "rm -rf #{destination}",
      "mv ${vlad_git_export_tmp}#{subdir} #{destination}"
      "rm -rf $vlad_git_export_tmp",
      "cd -",
      "cd .."
    ].join(" && ")
  end

  # Returns a command that maps human-friendly revision identifier
  # +revision+ into a git SHA1.

  def revision(revision)
    revision = 'HEAD' if revision =~ /head/i

    "`#{git_cmd} rev-parse #{revision}`"
  end

  private

  # Checks if fast-checkout is applicable
  def fast_checkout_applicable?(revision, destination)
    revision = 'HEAD' if revision =~ /head/i

    begin
      cmd = [ "if cd #{destination}",
              "#{git_cmd} rev-parse #{revision}",
              "#{git_cmd} remote -v | grep -q #{repository}",
              "cd -; then exit 0; else exit 1; fi &>/dev/null" ].join(" && ")
      run cmd
      return true
    rescue Rake::CommandFailedError
      return false
    end
  end

  def submodule_cmd
    %w(sync init update).map{|cmd| "#{git_cmd} submodule #{cmd}"}.join(" && ")
  end
end
