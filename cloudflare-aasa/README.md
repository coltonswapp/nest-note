# NestNote AASA (Password AutoFill)

Hosts `apple-app-site-association` for iOS Password AutoFill via **app.nestnoteapp.com**.

## Create the file locally

Create this folder structure (note: **no** `.json` extension on the filename):

```
cloudflare-aasa/
  public/
    .well-known/
      apple-app-site-association
```

Paste this exact content into `apple-app-site-association`:

```json
{
  "webcredentials": {
    "apps": ["X89M6X46Y8.com.Swappfunc.nest-note"]
  }
}
```

## Deploy to Cloudflare Pages (free)

1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com) → **Workers & Pages** → **Create** → **Pages** → **Upload assets**
2. Upload the **`public`** folder from this directory (not the whole `cloudflare-aasa` folder)
3. Deploy and note your `*.pages.dev` URL
4. In **Hostinger DNS**, add: `CNAME` `app` → `your-project.pages.dev`
5. In Cloudflare Pages → **Custom domains**, add `app.nestnoteapp.com`
6. Verify:

   ```bash
   curl https://app.nestnoteapp.com/.well-known/apple-app-site-association
   ```

7. In Xcode → **Associated Domains**, add:

   ```
   webcredentials:app.nestnoteapp.com
   ```

## File location after deploy

`https://app.nestnoteapp.com/.well-known/apple-app-site-association`
