//
//  RedditAdapter.swift
//  Notchly
//

import Foundation

struct RedditAdapter: WebNotificationAppAdapter {
    let id: WebNotificationAppID = .reddit
    let webURL = URL(string: "https://www.reddit.com/")!

    let badgeDetectionScript = """
    (function() {
      try {
        var node = document.querySelector('a[href*="/message/inbox"] span, faceplate-badge');
        if (!node) return 0;
        var n = parseInt((node.textContent || '').replace(/[^0-9]/g, ''), 10);
        return isNaN(n) ? 0 : n;
      } catch (e) { return null; }
    })();
    """

    let loginDetectionScript = """
    (function() {
      try {
        if (document.cookie.indexOf('reddit_session') === -1) return false;
        return !!document.querySelector('#USER_DROPDOWN_ID, [data-click-id="user_profile"]');
      } catch (e) { return null; }
    })();
    """

    let previewDetectionScript: String? = """
    (function() {
      try {
        var node = document.querySelector('a[href*="/message/inbox"] span, faceplate-badge');
        if (!node) return null;
        var n = parseInt((node.textContent || '').replace(/[^0-9]/g, ''), 10);
        if (isNaN(n) || n <= 0) return null;
        return JSON.stringify({
          title: 'Reddit',
          subtitle: n === 1 ? 'New notification' : (n + ' new notifications')
        });
      } catch (e) { return null; }
    })();
    """
}
