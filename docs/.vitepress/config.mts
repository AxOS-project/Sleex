import { defineConfig } from 'vitepress'

// https://vitepress.dev/reference/site-config
export default defineConfig({
  title: "Sleex desktop documentation",
  description: "A documentation about Sleex, the flagship desktop environment of AxOS",
  themeConfig: {
    // https://vitepress.dev/reference/default-theme-config
    nav: [
      { text: 'Home', link: '/' },
      { text: 'Docs', link: '/docs' }
    ],

    sidebar: [
      {
        text: 'Sleex shell',
        items: [
          { text: 'Desktop Shell Architecture', link: '/shell/overview' },
          { text: 'Overview and Launcher', link: '/shell/overview-and-launcher' },
          { text: 'Bar', link: '/shell/bar' },
          { text: 'Desktop', link: '/shell/desktop' },
          { text: 'Dock', link: '/shell/dock' },
          { text: 'Dashboard', link: '/shell/dashboard' },
          { text: 'Notifications and OSD', link: '/shell/notifications-and-osd' },
          { text: 'Utility Popups', link: '/shell/utility-popups' },
          { text: 'Lockscreen and Session', link: '/shell/lockscreen-and-session' }
        ]
      },
      {
        text: 'Sleex settings',
        items: [
          { text: 'Settings Center Architecture', link: '/settings/overview' },
          { text: 'About', link: '/settings/about' },
          { text: 'Applications', link: '/settings/applications' },
          { text: 'Behavior', link: '/settings/behavior' },
          { text: 'Connectivity', link: '/settings/connectivity' },
          { text: 'Display', link: '/settings/display' },
          { text: 'Interface', link: '/settings/interface' },
          { text: 'Security and Privacy', link: '/settings/security-and-privacy' },
          { text: 'Sound', link: '/settings/sound' },
          { text: 'Style', link: '/settings/style' }
        ]
      }
    ],

    socialLinks: [
      { icon: 'github', link: 'https://github.com/axos-project/sleex' }
    ]
  }
})
