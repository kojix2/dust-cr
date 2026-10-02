require "c/sys/stat"

module Dust
  # (inode, device) pair, used to detect hard links.
  alias FileId = Tuple(UInt64, UInt64)

  enum FileKind
    File
    Directory
    Symlink
    Other
  end

  record MetaData,
    size : UInt64,
    inode_device : FileId?,
    links : UInt64

  # Thin wrapper around libc's stat/lstat.
  #
  # Crystal's `File::Info` exposes neither inode/device nor `st_blocks`, both of
  # which dust needs (hard link detection and real disk usage), so every stat in
  # the program goes through here.
  module Platform
    extend self

    # All unix implementations report `st_blocks` in 512 byte units, no matter
    # what `st_blksize` says.
    BLOCK_SIZE = 512_u64

    # Slack for filesystems that pre-allocate more space than strictly needed.
    PREALLOC_BLOCKS = 65536_u64

    def lstat(path : String) : LibC::Stat?
      stat = uninitialized LibC::Stat
      if LibC.lstat(path, pointerof(stat)) == 0
        stat
      end
    end

    def stat(path : String) : LibC::Stat?
      stat = uninitialized LibC::Stat
      if LibC.stat(path, pointerof(stat)) == 0
        stat
      end
    end

    def kind_of(stat : LibC::Stat) : FileKind
      case stat.st_mode & LibC::S_IFMT
      when LibC::S_IFREG then FileKind::File
      when LibC::S_IFDIR then FileKind::Directory
      when LibC::S_IFLNK then FileKind::Symlink
      else                    FileKind::Other
      end
    end

    def get_metadata(path : String, apparent : Bool = false, follow_links : Bool = false) : MetaData?
      metadata_from(follow_links ? stat(path) : lstat(path), apparent)
    end

    # Same, from an already obtained stat (the walk stats every entry once).
    def metadata_from(stat : LibC::Stat?, apparent : Bool = false) : MetaData?
      return unless stat

      file_size = stat.st_size.to_u64
      inode_device = {stat.st_ino.to_u64, stat.st_dev.to_u64}
      links = stat.st_nlink.to_u64

      if apparent
        MetaData.new(file_size, inode_device, links)
      else
        blksize = stat.st_blksize.to_u64
        blksize = 4096_u64 if blksize == 0
        target_size = ((file_size + blksize - 1) // blksize) * blksize
        reported_size = stat.st_blocks.to_i64.to_u64 * BLOCK_SIZE
        max_size = target_size + blksize * PREALLOC_BLOCKS
        # Some filesystems report far more blocks than a file could ever use
        # (sparse files, preallocation). Never over-report.
        allocated_size = reported_size > max_size ? target_size : reported_size
        MetaData.new(allocated_size, inode_device, links)
      end
    end

    def device_of(path : String, follow_links : Bool = false) : UInt64?
      if metadata = get_metadata(path, false, follow_links)
        metadata.inode_device.try &.[1]
      end
    end
  end
end
