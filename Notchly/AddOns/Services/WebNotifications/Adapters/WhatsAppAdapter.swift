//
//  WhatsAppAdapter.swift
//  Notchly
//

import Foundation

struct WhatsAppAdapter: WebNotificationAppAdapter {
    let id: WebNotificationAppID = .whatsapp
    let webURL = URL(string: "https://web.whatsapp.com/")!

    let badgeDetectionScript = """
    (function() {
      try {
        var nodes = document.querySelectorAll('[aria-label*="unread"], span[class*="unread"]');
        var total = 0;
        nodes.forEach(function(el) {
          var label = el.getAttribute('aria-label') || el.textContent || '';
          var match = label.match(/\\d+/);
          if (match) total += parseInt(match[0], 10);
        });
        return total;
      } catch (e) { return null; }
    })();
    """

    let loginDetectionScript = """
    (function() {
      try {
        if (document.querySelector('canvas[aria-label*="Scan"]')) return false;
        return !!document.querySelector('#pane-side, [data-testid="chat-list"]');
      } catch (e) { return null; }
    })();
    """

    let previewDetectionScript: String? = """
    (function() {
      try {
        var rows = Array.from(document.querySelectorAll('#pane-side [role="listitem"], #pane-side [data-testid="cell-frame-container"]'));
        var target = rows.find(function(row) {
          var badge = row.querySelector('[aria-label*="unread"], span[class*="unread"], [data-testid="icon-unread-count"]');
          if (!badge) return false;
          var text = badge.getAttribute('aria-label') || badge.textContent || '';
          return /\\d/.test(text);
        });
        if (!target) return null;
        var title = (target.querySelector('[title]')?.getAttribute('title') || target.querySelector('span[dir=\"auto\"]')?.textContent || '').trim();
        var subtitle = (target.querySelector('[data-testid=\"last-msg-status\"]')?.nextElementSibling?.textContent || target.querySelector('[data-testid=\"msg-text\"]')?.textContent || '').trim();
        return JSON.stringify({
          title: title || 'WhatsApp',
          subtitle: subtitle || 'New message'
        });
      } catch (e) { return null; }
    })();
    """
}
