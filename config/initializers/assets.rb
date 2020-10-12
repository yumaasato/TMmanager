Rails.application.config.assets.version = '1.0'
Rails.application.config.assets.paths << Rails.root.join('node_modules')
Rails.application.config.assets.precompile += %w( admin.js 
                                                  admin.css 
                                                  users.css 
                                                  missions.css
                                                  button.css
                                                  index.js
                                                  scroll-polyfill.js
                                                  pace.js  )