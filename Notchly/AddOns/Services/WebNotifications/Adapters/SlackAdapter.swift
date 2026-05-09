//
//  SlackAdapter.swift
//  Notchly
//

import Foundation

struct SlackAdapter: WebNotificationAppAdapter {
    let id: WebNotificationAppID = .slack
    let webURL = URL(string: "https://app.slack.com/client")!

    let badgeDetectionScript = """
    (function() {
      try {
        var nodes = document.querySelectorAll('.p-channel_sidebar__badge, [data-qa="badge"]');
        var total = 0;
        nodes.forEach(function(el) {
          var n = parseInt((el.textContent || '').replace(/[^0-9]/g, ''), 10);
          if (!isNaN(n)) total += n;
        });
        return total;
      } catch (e) { return null; }
    })();
    """

    let loginDetectionScript = """
    (function() {
      try {
        if (window.location.pathname.indexOf('signin') !== -1) return false;
        return !!document.querySelector('.p-client, [data-qa="channel_sidebar"]');
      } catch (e) { return null; }
    })();
    """
}
