%%--------------------------------------------------------------------
%% Copyright (c) 2022-2023 EMQ Technologies Co., Ltd. All Rights Reserved.
%%--------------------------------------------------------------------

-module(emqx_s3).

-include_lib("emqx/include/types.hrl").

-export([
    start_profile/2,
    stop_profile/1,
    update_profile/2,
    start_uploader/2,
    with_client/2
]).

-export_type([
    profile_id/0,
    profile_config/0,
    acl/0
]).

-type profile_id() :: atom() | binary().

-type acl() ::
    private
    | public_read
    | public_read_write
    | authenticated_read
    | bucket_owner_read
    | bucket_owner_full_control.

-type transport_options() :: #{
    headers => map(),
    connect_timeout => pos_integer(),
    enable_pipelining => pos_integer(),
    max_retries => pos_integer(),
    pool_size => pos_integer(),
    pool_type => atom(),
    ipv6_probe => boolean(),
    ssl => map()
}.

-type profile_config() :: #{
    bucket := string(),
    access_key_id => string(),
    secret_access_key => emqx_secret:t(string()),
    host := string(),
    port := pos_integer(),
    url_expire_time := pos_integer(),
    acl => acl(),
    min_part_size => pos_integer(),
    transport_options => transport_options()
}.

-define(IS_PROFILE_ID(ProfileId), (is_atom(ProfileId) orelse is_binary(ProfileId))).

%%--------------------------------------------------------------------
%% API
%%--------------------------------------------------------------------

-spec start_profile(profile_id(), profile_config()) -> ok_or_error(term()).
start_profile(ProfileId, ProfileConfig) when ?IS_PROFILE_ID(ProfileId) ->
    case emqx_s3_sup:start_profile(ProfileId, ProfileConfig) of
        {ok, _} ->
            ok;
        {error, _} = Error ->
            Error
    end.

-spec stop_profile(profile_id()) -> ok_or_error(term()).
stop_profile(ProfileId) when ?IS_PROFILE_ID(ProfileId) ->
    emqx_s3_sup:stop_profile(ProfileId).

-spec update_profile(profile_id(), profile_config()) -> ok_or_error(term()).
update_profile(ProfileId, ProfileConfig) when ?IS_PROFILE_ID(ProfileId) ->
    emqx_s3_profile_conf:update_config(ProfileId, ProfileConfig).

-spec start_uploader(profile_id(), emqx_s3_uploader:opts()) ->
    supervisor:start_ret() | {error, profile_not_found}.
start_uploader(ProfileId, Opts) when ?IS_PROFILE_ID(ProfileId) ->
    emqx_s3_profile_uploader_sup:start_uploader(ProfileId, Opts).

-spec with_client(profile_id(), fun((emqx_s3_client:client()) -> Result)) ->
    {error, profile_not_found} | Result.
with_client(ProfileId, Fun) when is_function(Fun, 1) andalso ?IS_PROFILE_ID(ProfileId) ->
    case emqx_s3_profile_conf:checkout_config(ProfileId) of
        {ok, ClientConfig, _UploadConfig} ->
            try
                Fun(emqx_s3_client:create(ClientConfig))
            after
                emqx_s3_profile_conf:checkin_config(ProfileId)
            end;
        {error, _} = Error ->
            Error
    end.
