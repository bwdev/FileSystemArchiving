class ListMaker
require 'rubygems'
require 'pathname'

# TODO: HAVE TO CHANGE THIS WHEN ARCHIVE SERVER IS IN PLACE
ARCHIVE_PATH = "/tmp/archive_dev"

  def self.archive_files
    ARCHIVE.move_flags

    Fileserver.all.each do |fs|
       mnt_path = fs.mount_path
       LIST.make_list(mnt_path) unless mnt_path.nil?
    end
  end

########################### GENERATE A LIST OF FILES ON EACH FILESERVER ##############################

  class LIST 
    class << self

  ERRORS  = []
  LOGS    = []

      def make_list(str_path)
        _fileserver = Fileserver.find_by_mount_path(str_path)
        _fileserver.folders.destroy_all unless _fileserver.nil?

#        check_mount(str_path)
        check_mount(str_path) unless str_path == '/tmp/archive_dev' # NOTE: BECAUSE ARCHIVE IS NOT A MOUNT - THIS WILL CHANGE WHEN ARCHIVE SERVER IS UP
          Dir.chdir(str_path)
          folders = Dir["*"].select {|fn| File.directory?(fn)}

          folders.each do |item|
            next if item == '.' || item == '..'
            _jn = item.split("_").first

            f = Folder.new(:fileserver => _fileserver, 
                           :name => item, 
                           :status => check_jobnum(_jn), 
                           :project => Project.find_by_job_number(_jn))

            puts "#{item} saved!" if f.save
          end
          Dir.chdir("/etc")
        unmount(str_path) unless str_path == '/tmp/archive_dev' # NOTE: BECAUSE ARCHIVE IS NOT A MOUNT - THIS WILL CHANGE WHEN ARCHIVE SERVER IS UP
#        unmount(str_path)
      end 

      def check_mount(mount_path)
        pn = Pathname.new(mount_path)
        system("mount #{mount_path}") unless pn.mountpoint?
      end

      def unmount(mount_path)
        pn = Pathname.new(mount_path)
        system("umount #{mount_path}") if pn.mountpoint?
      end

      def check_jobnum(str=nil)
        _test = Project.find_by_job_number(str)
        return 'active' if _test && !_test.is_inactive? 
        return 'inactive' if _test && _test.is_inactive?
        return 'not found' if _test.nil?
      end

  
      end #class self
    end #class LIST


###################################################### ARCHIVE NOW #######################################################

  class ARCHIVE
    class << self
    
      def move_flags
        _move_me = Folder.where(:to_archive => true)
        unless _move_me.empty?
          _move_me.each do |fold|
            create_dirs(fold)
          end
        else
          puts "There is nothing flagged for archive"
        end
      end

      def create_dirs(folder=nil)
        _move_to = ""
        _check = folder.project.job_number

        Dir.chdir(ARCHIVE_PATH)
        folders = Dir["*"].select {|fn| File.directory?(fn)}
        res = folders.include?(_check)
        
        puts res 
        if res == true
          puts "Created #{ARCHIVE_PATH}/#{_check}/#{folder.fileserver.name}" if !File.directory?("#{ARCHIVE_PATH}/#{_check}/#{folder.fileserver.name}") && Dir.mkdir(File.join("#{ARCHIVE_PATH}/#{_check}", "#{folder.fileserver.name}"), 0774)
          puts "Created #{ARCHIVE_PATH}/#{_check}/#{folder.fileserver.name}/#{Time.now.strftime("%Y-%m-%d %H:%M")}" if Dir.mkdir(File.join("#{ARCHIVE_PATH}/#{_check}/#{folder.fileserver.name}", Time.now.strftime("%Y-%m-%d %H:%M")), 0774)
        else
          puts "Created #{_check}" if Dir.mkdir(File.join(ARCHIVE_PATH, "#{_check}"), 0774)
          puts "Created #{ARCHIVE_PATH}/#{_check}/#{folder.fileserver.name}" if !File.directory?("#{ARCHIVE_PATH}/#{_check}/#{folder.fileserver.name}") && Dir.mkdir(File.join("#{ARCHIVE_PATH}/#{_check}", "#{folder.fileserver.name}"), 0774)
          puts "Created #{ARCHIVE_PATH}/#{_check}/#{folder.fileserver.name}/#{Time.now.strftime("%Y-%m-%d %H:%M")}" if Dir.mkdir(File.join("#{ARCHIVE_PATH}/#{_check}/#{folder.fileserver.name}", Time.now.strftime("%Y-%m-%d %H:%M")), 0774)
        end
          
        LIST::check_mount(folder.fileserver.mount_path) unless folder.fileserver.mount_path.nil?

          _move_from = "#{folder.fileserver.mount_path}/#{folder.name}"
          _move_to = "#{ARCHIVE_PATH}/#{folder.project.job_number}/#{folder.fileserver.name}/#{Time.now.strftime("%Y-%m-%d %H:%M")}/"

#       Change attributes so the folders isn't archived again and again
#         TODO: NEED A BETTER WAY TO SET THE FILESERVER TO ARCHIVE       
          folder.fileserver = Fileserver.find_by_name('archive')
          folder.to_archive = false 
          folder.name = _check

#       TODO: WILL HAVE TO CHANGE THIS TO "MOVE" AND CHANGE MOUNTS TO R/W WHEN READY FOR DESTRUCTIVE TEST.
#        FileUtils.mv(_move_from, _move_to)
        puts "#{folder.name} has been archived!" if folder.save && FileUtils.cp_r(_move_from, _move_to)

        LIST::unmount(folder.fileserver.mount_path) unless folder.fileserver.mount_path.nil?
      end

      def directory_exists?(dir)
        File.directory?(dir)

      end

    end # end class self
  end #class ARCHIVE
  end #class ListMaker
