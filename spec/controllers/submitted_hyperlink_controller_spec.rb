describe SubmittedHyperlinkController do
  let(:admin) { build(:admin, id: 3) }
  let(:super_admin) { build(:superadmin, id: 1, role_id: 5) }
  let(:instructor1) { build(:instructor, id: 10, role_id: 3, parent_id: 3, name: 'Instructor1') }
  let(:student1) { build(:student, id: 21, role_id: 1) }
  let(:team) { build(:assignment_team, id: 1) }
  let(:participant) { build(:participant, id: 1, user_id: 21) }
  let(:assignment) { build(:assignment, id: 1) }
  describe '#action_allowed?' do
    context 'current user is not authorized' do
      it 'does not allow action for no user' do
        expect(controller.send(:action_allowed?)).to be false
      end
      it 'does not allow action for student without authorizations' do
        allow(controller).to receive(:current_user).and_return(build(:student))
        expect(controller.send(:action_allowed?)).to be false
      end
    end
    context 'current user has needed privileges' do
      it 'allows submit hyperlink action for students with team that can submit' do
        stub_current_user(student1, student1.role.name, student1.role)
        allow(controller).to receive(:one_team_can_submit_work?).and_return(true)
        controller.params = {action: 'submit_hyperlink'}
        expect(controller.send(:action_allowed?)).to be true
      end
      it 'allows action for admin' do
        stub_current_user(admin, admin.role.name, admin.role)
        expect(controller.send(:action_allowed?)).to be true
      end
      it 'allows action for super admin' do
        stub_current_user(super_admin, super_admin.role.name, super_admin.role)
        expect(controller.send(:action_allowed?)).to be true
      end
    end
  end
  describe '#controller_locale' do
    it 'should return I18n.default_locale' do
      user = student1
      stub_current_user(user, user.role.name, user.role)
      expect(controller.send(:controller_locale)).to eq(I18n.default_locale)
    end
  end
  describe '#submit_hyperlink' do
    context 'current user is participant and submits hyperlink' do
      before(:each) do
        allow(AssignmentParticipant).to receive(:find).and_return(participant)
        stub_current_user(student1, student1.role.name, student1.role)
        allow(participant).to receive(:team).and_return(team)
        allow(participant).to receive(:name).and_return('Name')
      end
      it 'flashes error if a duplicate hyperlink is submitted' do
        allow(team).to receive(:hyperlinks).and_return(['google.com'])
        params = {submission: "google.com", id: 21}
        response = get :submit_hyperlink, params: params
        expect(response).to redirect_to(action: :edit, id: 1)
        expect(flash[:error]).to eq 'You or your teammate(s) have already submitted the same hyperlink.'
      end
      it 'flashes error if url is invalid' do
        allow(team).to receive(:hyperlinks).and_return([])
        params = {submission: "abc123", id: 21}
        response = get :submit_hyperlink, params: params
        expect(response).to redirect_to(action: :edit, id: 1)
        expect(flash[:error]).to be_present # not checking message content since it uses #{$ERROR_INFO}
      end
    end
  end
  describe '#remove_hyperlink' do
    context 'current user is participant' do
      before(:each) do
        allow(AssignmentParticipant).to receive(:find).and_return(participant)
        stub_current_user(student1, student1.role.name, student1.role)
        allow(participant).to receive(:team).and_return(team)
        allow(team).to receive(:hyperlinks).and_return(['google.com'])
      end
      it 'redirects to edit if submissions are allowed' #do
        params = {id: 1}
        allow(assignment).to receive(:submission_allowed).and_return(true)
        response = get :remove_hyperlink, params
        expect(response).to redirect_to(action: :edit, id: 1)
      end
      it 'redirects to view if submissions are not allowed' #do
        params = {id: 1}
        allow(assignment).to receive(:submission_allowed).and_return(true)
        response = get :remove_hyperlink, params
        expect(response).to redirect_to(action: :view, id: 1)
      end
    end
  end
end
