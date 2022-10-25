module SubmittedHyperlinkHelper
  def display_hyperlink_in_peer_review_question(comments)
    html = ''
    html += link_to image_tag('/assets/tree_view/List-hyperlinks-24.png'), comments, target: '_blank'
    html
  end
end
