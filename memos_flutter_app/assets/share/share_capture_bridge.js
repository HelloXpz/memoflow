function memoflowCapture() {
  const normalize = (value) => {
    if (typeof value !== 'string') {
      return null;
    }
    const normalized = value.replace(/\s+/g, ' ').trim();
    return normalized.length > 0 ? normalized : null;
  };

  const readMeta = (selectors) => {
    for (const selector of selectors) {
      const element = document.querySelector(selector);
      const content = normalize(element && element.getAttribute('content'));
      if (content) {
        return content;
      }
    }
    return null;
  };

  const fallbackText = () => {
    const root = document.body || document.documentElement;
    return normalize(root && root.innerText ? root.innerText : '');
  };

  const ogTitle = readMeta([
    'meta[property="og:title"]',
    'meta[name="og:title"]',
    'meta[name="twitter:title"]'
  ]);
  const siteName = readMeta([
    'meta[property="og:site_name"]',
    'meta[name="application-name"]'
  ]);
  const description = readMeta([
    'meta[name="description"]',
    'meta[property="og:description"]',
    'meta[name="twitter:description"]'
  ]);
  const leadImageUrl = readMeta([
    'meta[property="og:image"]',
    'meta[name="twitter:image"]'
  ]);

  let parsed = null;
  let error = null;
  try {
    const clonedDocument = document.cloneNode(true);
    parsed = new Readability(clonedDocument).parse();
  } catch (captureError) {
    error = String(
      captureError && captureError.message ? captureError.message : captureError
    );
  }

  const parsedText = normalize(parsed && parsed.textContent ? parsed.textContent : null);
  const textContent = parsedText || fallbackText();
  const contentHtml =
    parsed && typeof parsed.content === 'string' && parsed.content.trim().length > 0
      ? parsed.content
      : null;

  return {
    finalUrl: String(location && location.href ? location.href : ''),
    pageTitle: normalize(document.title),
    articleTitle: normalize(parsed && parsed.title ? parsed.title : ogTitle),
    siteName: normalize(parsed && parsed.siteName ? parsed.siteName : siteName),
    byline: normalize(parsed && parsed.byline ? parsed.byline : null),
    excerpt: normalize(parsed && parsed.excerpt ? parsed.excerpt : description),
    contentHtml: contentHtml,
    textContent: textContent,
    leadImageUrl: normalize(leadImageUrl),
    length: textContent ? textContent.length : 0,
    readabilitySucceeded: !!contentHtml,
    error: error,
  };
}
