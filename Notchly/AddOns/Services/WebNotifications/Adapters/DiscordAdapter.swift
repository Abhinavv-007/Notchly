//
//  DiscordAdapter.swift
//  Notchly
//

import Foundation

struct DiscordAdapter: WebNotificationAppAdapter {
    let id: WebNotificationAppID = .discord
    let webURL = URL(string: "https://discord.com/channels/@me")!

    let badgeDetectionScript = """
    (function() {
      try {
        var badges = document.querySelectorAll('[class*="numberBadge"], [class*="NumberBadge"]');
        var total = 0;
        badges.forEach(function(el) {
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
        if (window.location.pathname.indexOf('/login') !== -1) return false;
        return !!document.querySelector('[class*="guilds"], [class*="Guilds"]');
      } catch (e) { return null; }
    })();
    """

    let previewDetectionScript: String? = """
    (function() {
      try {
        var badges = document.querySelectorAll('[class*="numberBadge"], [class*="NumberBadge"]');
        var total = 0;
        badges.forEach(function(el) {
          var n = parseInt((el.textContent || '').replace(/[^0-9]/g, ''), 10);
          if (!isNaN(n)) total += n;
        });
        if (!total) return null;
        return JSON.stringify({
          title: 'Discord',
          subtitle: total === 1 ? 'New notification' : (total + ' new notifications')
        });
      } catch (e) { return null; }
    })();
    """
}
