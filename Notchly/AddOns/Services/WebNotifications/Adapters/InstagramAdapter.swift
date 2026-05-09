//
//  InstagramAdapter.swift
//  Notchly
//

import Foundation

struct InstagramAdapter: WebNotificationAppAdapter {
    let id: WebNotificationAppID = .instagram
    let webURL = URL(string: "https://www.instagram.com/direct/inbox/")!

    let badgeDetectionScript = """
    (function() {
      try {
        var node = document.querySelector('a[href*="/direct/"] [aria-label*="unread"], span[class*="unread"]');
        if (!node) return 0;
        var n = parseInt((node.textContent || '').replace(/[^0-9]/g, ''), 10);
        return isNaN(n) ? 0 : n;
      } catch (e) { return null; }
    })();
    """

    let loginDetectionScript = """
    (function() {
      try {
        if (window.location.pathname.indexOf('/accounts/login') !== -1) return false;
        return !!document.querySelector('nav, [role="navigation"]');
      } catch (e) { return null; }
    })();
    """

    let previewDetectionScript: String? = """
    (function() {
      try {
        var row = document.querySelector('a[href*="/direct/t/"]');
        if (!row) return null;
        var title = (row.querySelector('span[dir=\"auto\"]')?.textContent || row.textContent || '').trim();
        return JSON.stringify({
          title: title || 'Instagram',
          subtitle: 'New direct message'
        });
      } catch (e) { return null; }
    })();
    """
}
