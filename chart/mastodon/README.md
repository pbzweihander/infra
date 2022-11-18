Source: https://github.com/mastodon/mastodon/tree/628b3fa44916dba1bcb24af0a92b49edc4bf49ce/chart

Modified...

- `ingress.yaml`, `service-web.yaml`, and `service-streaming.yaml` files for using AWS load balancer controller
- `Chart.yaml`, and `configmap-env.yaml` files for using existing Redis
- `_helpers.tpl` file to fix some bugs
- `deployment-sidekiq.yaml`, `deployment-streaming.yaml`, and `deployment-web.yaml` files for custom pod affinity
