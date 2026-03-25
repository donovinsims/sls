import { useEffect } from "react";

interface SEOHeadProps {
  title: string;
  description: string;
  path: string;
  ogImage?: string;
  noindex?: boolean;
}

const SITE_URL = "https://slscourse.lovable.app";
const DEFAULT_OG_IMAGE = "https://storage.googleapis.com/gpt-engineer-file-uploads/attachments/og-images/5c460bab-a8da-481c-b394-266d3dd8a605";

/**
 * Manages document <head> tags for SEO.
 * Sets title, meta description, canonical, OG & Twitter tags.
 */
const SEOHead = ({ title, description, path, ogImage, noindex }: SEOHeadProps) => {
  const canonicalUrl = `${SITE_URL}${path}`;
  const image = ogImage ?? DEFAULT_OG_IMAGE;

  useEffect(() => {
    document.title = title;

    const setMeta = (name: string, content: string, attr = "name") => {
      let el = document.querySelector(`meta[${attr}="${name}"]`) as HTMLMetaElement | null;
      if (!el) {
        el = document.createElement("meta");
        el.setAttribute(attr, name);
        document.head.appendChild(el);
      }
      el.setAttribute("content", content);
    };

    setMeta("description", description);
    setMeta("robots", noindex ? "noindex, nofollow" : "index, follow");

    // Canonical
    let link = document.querySelector('link[rel="canonical"]') as HTMLLinkElement | null;
    if (!link) {
      link = document.createElement("link");
      link.setAttribute("rel", "canonical");
      document.head.appendChild(link);
    }
    link.setAttribute("href", canonicalUrl);

    // OG
    setMeta("og:title", title, "property");
    setMeta("og:description", description, "property");
    setMeta("og:url", canonicalUrl, "property");
    setMeta("og:image", image, "property");
    setMeta("og:type", "website", "property");

    // Twitter
    setMeta("twitter:card", "summary_large_image");
    setMeta("twitter:title", title);
    setMeta("twitter:description", description);
    setMeta("twitter:image", image);
  }, [title, description, canonicalUrl, image, noindex]);

  return null;
};

export default SEOHead;
