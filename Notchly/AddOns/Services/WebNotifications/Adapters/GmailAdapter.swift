//
//  GmailAdapter.swift
//  Notchly
//

import Foundation

struct GmailAdapter: WebNotificationAppAdapter {
    let id: WebNotificationAppID = .gmail
    let webURL = URL(string: "https://mail.google.com/mail/u/0/#inbox")!

    let badgeDetectionScript = """
    (function() {
      try {
        var link = document.querySelector('a[href*="#inbox"] .bsU, a[aria-label*="Inbox"] .bsU');
        if (!link) return null;
        var raw = (link.textContent || '').replace(/[^0-9]/g, '');
        if (!raw.length) return 0;
        return parseInt(raw, 10) || 0;
      } catch (e) { return null; }
    })();
    """

    let loginDetectionScript = """
    (function() {
      try {
        var url = window.location.href;
        if (url.indexOf('accounts.google.com') !== -1) return false;
        return !!document.querySelector('[aria-label="Inbox"], [role="main"]');
      } catch (e) { return null; }
    })();
    """

    let previewDetectionScript: String? = """
    (function() {
      try {
        var row = document.querySelector('tr.zE');
        if (!row) return null;
        var sender = (row.querySelector('.yP, .zF')?.textContent || '').trim();
        var subject = (row.querySelector('.bog')?.textContent || '').trim();
        var snippet = (row.querySelector('.y2')?.textContent || '').trim();
        var subtitle = [subject, snippet].filter(Boolean).join(' • ');
        return JSON.stringify({
          title: sender || 'Gmail',
          subtitle: subtitle || 'New message'
        });
      } catch (e) { return null; }
    })();
    """
}
