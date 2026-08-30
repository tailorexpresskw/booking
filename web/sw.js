self.addEventListener('install', function () {
  self.skipWaiting();
});

self.addEventListener('activate', function (event) {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('push', function (event) {
  var data = {};
  if (event.data) {
    try {
      data = event.data.json();
    } catch (error) {
      data = { body: event.data.text() };
    }
  }
  var title = data.title || 'Tailor Express';
  var options = {
    body: data.body || 'New staff update.',
    icon: data.icon || '/icons/tailor-logo-192.png',
    badge: data.badge || '/icons/tailor-logo-192.png',
    tag: data.orderId ? 'tailor-express-' + data.orderId : 'tailor-express-staff',
    renotify: true,
    data: {
      url: data.url || '/staff'
    }
  };
  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', function (event) {
  event.notification.close();
  var target = (event.notification.data && event.notification.data.url) || '/staff';
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (clients) {
      for (var i = 0; i < clients.length; i++) {
        if ('focus' in clients[i]) {
          return clients[i].focus();
        }
      }
      return self.clients.openWindow(target);
    })
  );
});
