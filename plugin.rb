# name: discourse-publish-direct-messages
# about: Allows you to publish direct messages.
# version: 0.1
# authors: Thijs Brilleman
# url: https://github.com/thijsbrilleman/discourse-publish-direct-messages

enabled_site_setting :publish_direct_messages_enabled

module CustomPmParams

  def get_pm_params(topic)

    is_published = topic.tags.map(&:name).include?('published')
    if (@user.blank? && is_published) 
      return {
        topic: topic,
        my_group_ids: [], # my_group_ids,
        target_group_ids: [], # target_group_ids,
        target_user_ids: [], # target_user_ids,
      }
    end

    # Call the original method if not published
    super(topic)
  end
end

module CustomCheckAndRaiseExceptions

  def check_and_raise_exceptions(skip_staff_action)

    raise Discourse::NotFound if @topic.blank?
    # Special case: If the topic is private and the user isn't logged in, ask them
    # to log in!
    is_published = @topic.tags.map(&:name).include?('published')
    raise Discourse::NotLoggedIn.new if @topic.present? && @topic.private_message? && (@user.blank? && !is_published)

    # can user see this topic?
    unless @guardian.can_see?(@topic) || is_published
      raise Discourse::InvalidAccess.new("can't see #{@topic}", @topic)
    end

    # log personal message views
    if SiteSetting.log_personal_messages_views && !skip_staff_action && @topic.present? &&
         @topic.private_message? && @topic.all_allowed_users.where(id: @user.id).blank?
      unless UserHistory
               .where(
                 acting_user_id: @user.id,
                 action: UserHistory.actions[:check_personal_message],
                 topic_id: @topic.id,
               )
               .where("created_at > ?", 1.hour.ago)
               .exists?
        StaffActionLogger.new(@user).log_check_personal_message(@topic)
      end
    end
  end
end

after_initialize do
  TopicQuery.prepend CustomPmParams
  TopicView.prepend CustomCheckAndRaiseExceptions
end