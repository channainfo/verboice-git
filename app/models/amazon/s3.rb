# Copyright (C) 2010-2012, InSTEDD
#
# This file is part of Verboice.
#
# Verboice is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Verboice is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Verboice.  If not, see <http://www.gnu.org/licenses/>.

module Amazon
  class S3
    CONFIG_FILE_PATH = "#{Rails.root}/config/aws.yml"
    BUCKET_NAME = 'verboice-cambodia'

    def initialize
      @s3 = AWS::S3.new
    end

    class << self
      def upload file
        instance = Amazon::S3.new
        instance.upload file
      end

      def restore year, month, type
        instance = Amazon::S3.new
        instance.restore year, month, type
      end
    end

    def upload file
      if file
        p "=============== uploading to amazon s3 ==============="
        @key = File.basename(file)
        @bucket = @s3.buckets[BUCKET_NAME]
        @object = @bucket.objects[@key]
        @object.write Pathname.new(file)
        p "=============== done ==============="
      else
        raise "file can't be null"
      end
    end

    def restore year, month, type
      p "=============== retrieving objects from amazon s3 ==============="
      @objects = []
      pattern = "^"
      pattern << Regexp.escape("#{year}") << Regexp.escape("#{'%02d' % month}")
      pattern << ".*"
      pattern << Regexp.escape("#{type}.tar.gz") << "$"
      regex = Regexp.new pattern
      @bucket = @s3.buckets[BUCKET_NAME]
      @bucket.objects.each do |obj|
        if obj.key.match regex
          @objects.push obj
          break if type == Backup::FULL
        end
      end
      @objects
    end

  end
end