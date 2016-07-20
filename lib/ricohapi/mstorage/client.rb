# Copyright (c) 2016 Ricoh Company, Ltd. All Rights Reserved.
# See LICENSE for more information

module RicohAPI
  module MStorage
    class Client
      attr_accessor :token

      class Error < StandardError; end
      class Unauthorized < Error; end

      User_meta_regex = /^user\.([A-Za-z0-9_\-]{1,256})$/

      def initialize(access_token)
        self.token = Auth::AccessToken.new access_token
      end

      # GET /media
      def list(params = {})
        params.reject! do |k, v|
          ![:after, :before, :limit].include? k.to_sym
        end
        handle_response do
          token.get endpoint_for('media'), params
        end
      end

      # GET /media/{id}
      def info(media_id)
        handle_response do
          token.get endpoint_for("media/#{media_id}")
        end
      end

      # GET /media/{id}/content
      def download(media_id)
        handle_response(:as_raw) do
          token.get endpoint_for("media/#{media_id}/content")
        end
      end

      # GET /media/{id}/meta, GET /media/{id}/meta/exif, GET /media/{id}/meta/gpano,
      # GET /media/{id}/meta/user, GET /media/{id}/meta/user/{key}
      def meta(media_id, field_name = nil)
        unless field_name
          # GET /media/{id}/meta
          handle_response do
            token.get endpoint_for("media/#{media_id}/meta")
          end
        else
          if ['exif', 'gpano', 'user'].include? field_name
            # GET /media/{id}/meta/exif, GET /media/{id}/meta/gpano, GET /media/{id}/meta/user
            handle_response do
              token.get endpoint_for("media/#{media_id}/meta/#{field_name}")
            end
          else
            if User_meta_regex =~ field_name
              # GET /media/{id}/meta/user/{key}
              handle_response(:as_raw) do
                token.get endpoint_for("media/#{media_id}/meta/user/#{$1}")
              end
            else
              raise Error.new("invalid fieldName: #{field_name}")
            end
          end
        end
      end

      # POST /media (multipart)
      def upload(media)
        handle_response do
          token.post endpoint_for('media'), media
        end
      end

      # DELETE /media/{id}
      def delete(media_id)
        handle_response(:as_raw) do
          token.delete endpoint_for("media/#{media_id}")
        end
      end

      # PUT /media/{id}/meta/user/{key}
      def add_meta(media_id, user_meta)
        # TODO: do something
      end

      # DELETE /media/{id}/meta/user, DELETE /media/{id}/meta/user/{key}
      def remove_meta(media_id, key)
        # TODO: do something
      end

      def tags(params = {})
        handle_response do
          token.get endpoint_for('tags')
        end
      end

      def tags_on(media_id)
        handle_response do
          token.get endpoint_for("media/#{media_id}/tags")
        end
      end

      def tags_to(media_id, tag)
        handle_response do
          token.post endpoint_for("media/#{media_id}/tags"), {
            name: tag
          }.to_json, {'Content-Type': 'application/json'}
        end
      end

      private

      def handle_response(as_raw = false, retrying = false)
        response = yield
        case response.status
        when 200...300
          if as_raw
            response.body
          else
            _response_ = MultiJson.load response.body
            _response_.with_indifferent_access if _response_.respond_to? :with_indifferent_access
          end
        when 401
          raise Unauthorized.new('API access expired or revoked, please re-login.')
        else
          raise Error.new('Unknown API Error')
        end
      end

      def endpoint_for(path)
        File.join BASE_URL, path
      end
    end
  end
end
