/* eslint-disable camelcase */
/**
 * Parses the broadcast object on the document into JSON.
 *
 * @function broadcastData
 */
function broadcastData() {
  const { broadcast = null } = document.body.dataset;

  return JSON.parse(broadcast);
}

/**
 * Inserts the broadcast's HTML into `active-broadcast` element
 * as the first child within the document's body, and only inserts the HTML once.
 *
 * @function initializeBroadcast
 */
function initializeBroadcast() {
  const data = broadcastData();
  if (!data) {
    return;
  }
  const { html, banner_class } = data;
  const el = document.getElementById('active-broadcast');

  if (el.firstElementChild) {
    return; // Only append HTML once, on first render.
  }

  if (banner_class) {
    // FIXME: clean this up!
    const classes = banner_class.split(' ');
    if (classes[0]) {
      el.classList.add(classes[0]);
    }
    if (classes[1]) {
      el.classList.add(classes[1]);
    }
  }

  const closeButton = `<button class="close-announcement">
    <svg width="14" height="14" viewBox="0 0 14 14" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path d="M6.99974 5.58623L11.9497 0.63623L13.3637 2.05023L8.41374 7.00023L13.3637 11.9502L11.9497 13.3642L6.99974 8.41423L2.04974 13.3642L0.635742 11.9502L5.58574 7.00023L0.635742 2.05023L2.04974 0.63623L6.99974 5.58623Z" fill="white" />
    </svg>
  </button>`;

  const bannerDiv = `<div class='broadcast-data'>${html}</div>${closeButton}`;
  el.insertAdjacentHTML('afterbegin', bannerDiv);
}
/* eslint-enable camelcase */
