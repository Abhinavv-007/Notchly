//
//  TelegramAdapter.swift
//  Notchly
//

import Foundation

struct TelegramAdapter: WebNotificationAppAdapter {
    let id: WebNotificationAppID = .telegram
    let webURL = URL(string: "https://web.telegram.org/k/")!

    let badgeDetectionScript = """
    (function() {
      try {
        var nodes = document.querySelectorAll('.badge-unread, .dialog-subtitle-badge, .badge');
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
        return !!document.querySelector('.chatlist, .dialogs-container');
      } catch (e) { return null; }
    })();
    """

    let previewDetectionScript: String? = """
    (function() {
      try {
        var rows = Array.from(document.querySelectorAll('.chatlist-chat, .dialog-list-item, [data-peer-id]'));
        var target = rows.find(function(row) {
          var badge = row.querySelector('.badge-unread, .dialog-subtitle-badge, .badge');
          if (!badge) return false;
          var n = parseInt((badge.textContent || '').replace(/[^0-9]/g, ''), 10);
          return !isNaN(n) && n > 0;
        });
        if (!target) return null;
        var title = (target.querySelector('.user-title, .fullName, .chatlist-chat .title')?.textContent || '').trim();
        var subtitle = (target.querySelector('.message, .last-message, .chatlist-chat .subtitle')?.textContent || '').trim();
        return JSON.stringify({
          title: title || 'Telegram',
          subtitle: subtitle || 'New message'
        });
      } catch (e) { return null; }
    })();
    """
}
