class SubmittedHyperlinkController < ApplicationController
  require 'mimemagic'
  require 'mimemagic/overlay'

  include AuthorizationHelper

  before_action :ensure_current_user_is_participant, only: %i[submit_hyperlink]

  # Validate whether a particular action is allowed by the current user or not based on the privileges
  def action_allowed?
    case params[:action]
    when 'submit_hyperlink'
      current_user_has_student_privileges? &&
        one_team_can_submit_work?
    else
      current_user_has_student_privileges?
    end
  end

  def controller_locale
    locale_for_student
  end

  # submit_hyperlink is called when a new hyperlink is added to an assignment
  def submit_hyperlink
    team = @participant.team
    team_hyperlinks = team.hyperlinks
    if team_hyperlinks.include?(params['submission'])
      ExpertizaLogger.error LoggerMessage.new(controller_name, @participant.name, 'You or your teammate(s) have already submitted the same hyperlink.', request)
      flash[:error] = 'You or your teammate(s) have already submitted the same hyperlink.'
    else
      begin
        team.submit_hyperlink(params['submission'])
        SubmissionRecord.create(team_id: team.id,
                                content: params['submission'],
                                user: @participant.name,
                                assignment_id: @participant.assignment.id,
                                operation: 'Submit Hyperlink')
      rescue StandardError
        ExpertizaLogger.error LoggerMessage.new(controller_name, @participant.name, "The URL or URI is invalid. Reason: #{$ERROR_INFO}", request)
        flash[:error] = "The URL or URI is invalid. Reason: #{$ERROR_INFO}"
      end
      @participant.mail_assigned_reviewers
      ExpertizaLogger.info LoggerMessage.new(controller_name, @participant.name, 'The link has been successfully submitted.', request)
      undo_link('The link has been successfully submitted.')
    end
    redirect_to action: 'edit', id: @participant.id
  end

  # remove_hypelink is called when an existing hyperlink is removed from an assignment
  def remove_hyperlink
    @participant = AssignmentParticipant.find(params[:hyperlinks][:participant_id])
    return unless current_user_id?(@participant.user_id)

    team = @participant.team
    hyperlink_to_delete = team.hyperlinks[params['chk_links'].to_i]
    team.remove_hyperlink(hyperlink_to_delete)
    ExpertizaLogger.info LoggerMessage.new(controller_name, @participant.name, 'The link has been successfully removed.', request)
    undo_link('The link has been successfully removed.')
    # determine if the user should be redirected to "edit" or  "view" based on the current deadline
    topic_id = SignedUpTeam.topic_id(@participant.parent_id, @participant.user_id)
    assignment = Assignment.find(@participant.parent_id)
    SubmissionRecord.create(team_id: team.id,
                            content: hyperlink_to_delete,
                            user: @participant.name,
                            assignment_id: assignment.id,
                            operation: 'Remove Hyperlink')
    action = (assignment.submission_allowed(topic_id) ? 'edit' : 'view')
    redirect_to action: action, id: @participant.id
  end

  # if one team do not hold a topic (still in waitlist), they cannot submit their work.
  def one_team_can_submit_work?
    @participant = if params[:id].nil?
                     AssignmentParticipant.find(params[:hyperlinks][:participant_id])
                   else
                     AssignmentParticipant.find(params[:id])
                   end
    @topics = SignUpTopic.where(assignment_id: @participant.parent_id)
    # check one assignment has topics or not
    (!@topics.empty? && !SignedUpTeam.topic_id(@participant.parent_id, @participant.user_id).nil?) || @topics.empty?
  end

  def ensure_current_user_is_participant
    @participant = AssignmentParticipant.find(params[:id])
    return unless current_user_id?(@participant.user_id)
  end
end
