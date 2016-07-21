# Copyright (c) 2016 Ricoh Company, Ltd. All Rights Reserved.
# See LICENSE for more information

module RicohAPI
  module MStorage
    class Client
      attr_accessor :token

      class Error < StandardError; end

      SEARCH_VERSION = '2016-07-08'
      USER_META_REGEX = /^user\.([A-Za-z0-9_\-]{1,256})$/
      MAX_USER_META_LENGTH = 1024
      MIN_USER_META_LENGTH = 1

      def initialize(access_token)
        self.token = Auth::AccessToken.new access_token
      end

      # GET /media
      def list(params = {})
        params.reject! do |k, v|
          ![:after, :before, :limit, :filter].include? k.to_sym
        end
        if params.include? :filter
          handle_response do
            token.post endpoint_for('media/search'), {
              search_veresion: SEARCH_VERSION,
              query: params[:filter],
              paging: {
                before: params[:before],
                after: params[:after],
                limit: params[:limit]
              }
            }.to_json, {'Content-Type': 'application/json'}
          end
        else
          handle_response do
            token.get endpoint_for('media'), params
          end
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
        case field_name
        when nil
          handle_response do
            token.get endpoint_for("media/#{media_id}/meta")
          end
        when 'exif', 'gpano', 'user'
          handle_response do
            token.get endpoint_for("media/#{media_id}/meta/#{field_name}")
          end
        when USER_META_REGEX
          handle_response(:as_raw) do
            token.get endpoint_for("media/#{media_id}/meta/user/#{$1}")
          end
        else
          raise Error.new("invalid field_name: #{field_name}")
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
        raise Error.new("user_meta is empty: nothing to request.") if user_meta.empty?
        user_meta.each do |k, v|
          validate(v)
          if k.empty?
            raise Error.new("Invalid parameter: One of the given keys is empty")
          end
          USER_META_REGEX =~ k
          handle_response(:as_raw) do
            token.put endpoint_for("media/#{media_id}/meta/user/#{$1}"), v, {'Content-Type': 'text/plain'}
          end
        end
      end

      # DELETE /media/{id}/meta/user, DELETE /media/{id}/meta/user/{key}
      def remove_meta(media_id, key)
        # TODO: do something
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
        else
          begin
            raise Error.new("Status code #{response.status}: #{JSON.parse(response.body)["reason"]}")
          rescue JSON::ParserError
            raise Error.new("Status code #{response.status}: Unexpected response: #{response.body}")
          end
        end
      end

      def endpoint_for(path)
        File.join BASE_URL, path
      end

      def validate(value)
        raise Error.new("Invalid parameter: One of the given values is too big or too small: #{value}") unless (MIN_USER_META_LENGTH..MAX_USER_META_LENGTH).include? value.length
        true
      end
    end
  end
end
