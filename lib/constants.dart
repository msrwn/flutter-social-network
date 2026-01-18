library constants;

const FINISHED_ON_BOARDING = 'finishedOnBoarding';

/// color accent of the primary color
const COLOR_ACCENT = 0xFF78a3ff;

/// alternative color to the primary color, commonly this is used on android's
/// status bar
const COLOR_PRIMARY_DARK = 0xFF004ab5;

/// main color of the app, to change this replace
/// the code after the prefix '0xFF'
const COLOR_PRIMARY = 0xFF3875E8;
const FACEBOOK_BUTTON_COLOR = 0xFF415893;

/// database table/field names, use constants to avoid spelling mistakes
const USERS = 'users';
const CHANNEL_PARTICIPATION = 'channel_participation';
const CHANNELS = 'channels';
const THREAD = 'thread';
const REPORTS = 'reports';
const STORIES = 'socialnetwork_stories';
const FEED = 'social_feeds';
const MAIN_FEED = 'main_feed';
const STORIES_FEED = 'stories_feed';
const SOCIAL_COMMENTS = 'socialnetwork_comments';
const SOCIAL_REACTIONS = 'socialnetwork_reactions';
const SOCIAL_DISCOVER = 'SocialNetwork_Posts';
const NOTIFICATIONS = 'notifications';
const SOCIAL_GRAPH = 'social_graph';
const RECEIVED_FRIEND_REQUESTS = 'inbound_users';
const SENT_FRIEND_REQUESTS = 'outbound_users';

/// helpful formatting constants
const SECOND_MILLIS = 1000;
const MINUTE_MILLIS = 60 * SECOND_MILLIS;
const HOUR_MILLIS = 60 * MINUTE_MILLIS;

/// this server key is used to send notifications, use your own server key,
/// you can find this in your firebase project settings
const SERVER_KEY =
    'AAAAZz4RcfQ:APA91bEljtQ-DRJv3ZIXNR__lrY3m9puCSx9GeHs619bqhVDSwzo1tnXSZEYU0eMN1WNOvoeTx6Mkc_vSEaoJ65HCf_1BKXnGHQA9dwF3II4rH9I3YvUkWYCW2ocyGWqLS-pUYIr_ux-';

/// google api key, this is required when using google services such as
/// google maps, google places etc...
const GOOGLE_API_KEY = 'AIzaSyBiglGUXQZBkvBVlmO87P8Z_SKNnwWkA_g';
