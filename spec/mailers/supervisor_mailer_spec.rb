require "rails_helper"

RSpec.describe SupervisorMailer, type: :mailer do
  describe ".weekly_digest" do
    let(:supervisor) { build(:supervisor, :receive_reimbursement_attachment) }
    let(:volunteer) { build(:volunteer, casa_org: supervisor.casa_org, supervisor: supervisor) }
    let(:casa_case) { build(:casa_case, casa_org: supervisor.casa_org) }

    let(:mail) { SupervisorMailer.weekly_digest(supervisor) }

    context "when a supervisor has volunteer assigned to a casa case" do
      let!(:case_assignment) { create(:case_assignment, casa_case: casa_case, volunteer: volunteer) }

      it "shows a summary for a volunteer assigned to the supervisor" do
        expect(mail.body.encoded).to match("Summary for <a href=\"#{edit_volunteer_url(volunteer)}\">#{volunteer.display_name}</a>")
      end

      it "does not show a case contact that did not occurr in the week" do
        build_stubbed(:case_contact, casa_case: casa_case, occurred_at: Date.today - 8.days)
        expect(mail.body.encoded).to_not match("Most recent contact attempted:")
      end

      it "shows the latest case contact that occurred in the week" do
        most_recent_contact = create(:case_contact, casa_case: casa_case, occurred_at: Date.today - 1.days, notes: "AAAAAAAAAAAAAAAAAAAAAAAA")
        other_contact = build(:case_contact, casa_case: casa_case, occurred_at: Date.today - 3.days, notes: "BBBBBBBBBBBBBBBBBBBB")

        expect(mail.body.encoded).to match("Notes: #{most_recent_contact.notes}")
        expect(mail.body.encoded).to_not match("Notes: #{other_contact.notes}")
      end

      it "has a CSV attachment" do
        expect(mail.attachments.count).to eq(1)
      end
    end

    context "when a supervisor has a volunteer who is unassigned from a casa case during the week" do
      let!(:case_assignment) { create(:case_assignment, casa_case: casa_case, volunteer: volunteer, active: false, updated_at: Date.today - 2.days) }

      it "shows a summary for a volunteer recently unassigned from the supervisor" do
        expect(mail.body.encoded).to match("Summary for <a href=\"#{edit_volunteer_url(volunteer)}\">#{volunteer.display_name}</a>")
      end

      it "shows a disclaimer for a volunteer recently unassigned from the supervisor" do
        expect(mail.body.encoded).to match("This case was unassigned from #{volunteer.display_name}")
      end

      it "does not show a case contact that occurred past the unassignment date in the week" do
        contact_past_unassignment = build_stubbed(:case_contact, casa_case: casa_case, occurred_at: Date.today - 1.days, notes: "AAAAAAAAAAAAAAAAAAAAAAAA")

        expect(mail.body.encoded).to_not match("Notes: #{contact_past_unassignment.notes}")
      end

      it "shows the latest case contact that occurred in the week before the unassignment date" do
        contact_past_unassignment = create(:case_contact, casa_case: casa_case, occurred_at: Date.today - 1.days, notes: "AAAAAAAAAAAAAAAAAAAAAAAA")
        most_recent_contact_before_unassignment = create(:case_contact, casa_case: casa_case, occurred_at: Date.today - 3.days, notes: "BBBBBBBBBBBBBBBBBB")
        older_contact = build_stubbed(:case_contact, casa_case: casa_case, occurred_at: Date.today - 4.days, notes: "CCCCCCCCCCCCCCCCCCCC")

        expect(mail.body.encoded).to match("Notes: #{most_recent_contact_before_unassignment.notes}")
        expect(mail.body.encoded).to_not match("Notes: #{contact_past_unassignment.notes}")
        expect(mail.body.encoded).to_not match("Notes: #{older_contact.notes}")
      end
    end

    it "does not show a summary for a volunteer unassigned from the supervisor before the week" do
      create(:case_assignment, casa_case: casa_case, volunteer: volunteer, active: false, updated_at: Date.today - 8.days)
      expect(mail.body.encoded).to_not match("Summary for #{volunteer.display_name}")
    end

    context "when a supervisor has pending volunteer to accepts invitation" do
      let(:volunteer2) { create(:volunteer) }
      before do
        volunteer2.invite!(supervisor)
      end

      it "shows a summary of pending volunteers" do
        expect(mail.body.encoded).to match(volunteer2.display_name.to_s)
      end

      it "has a button to re-invite volunteer" do
        expect(mail.body.encoded).to match("<a href=\"#{resend_invitation_volunteer_url(volunteer2)}\">")
      end

      it "do not shows a summary of pending volunteers if the volunteer already accepted" do
        volunteer2.invitation_accepted_at = DateTime.current
        volunteer2.save

        expect(mail.body.encoded).to_not match(volunteer2.display_name.to_s)
      end

      it "does not display 'There are no pending volunteers' message when there are pending volunteers" do
        expect(mail.body.encoded).to_not match("There are no pending volunteers.")
      end
    end

    it "displays no pending volunteers message when there are no pending volunteers" do
      expect(mail.body.encoded).to match("There are no pending volunteers.")
    end

    it "does not display 'There are no additional notes' message when there are additional notes" do
      create(:case_assignment, casa_case: casa_case, volunteer: volunteer, active: false, updated_at: Date.today + 8.days)
      expect(mail.body.encoded).to_not match("There are no additional notes.")
    end

    it "displays no additional notes messsage when there are no additional notes" do
      expect(mail.body.encoded).to match("There are no additional notes.")
    end
  end

  describe ".invitation_instructions for a supervisor" do
    let(:supervisor) { create(:supervisor) }
    let(:mail) { supervisor.invite! }
    let(:expiration_date) { I18n.l(supervisor.invitation_due_at, format: :full, default: nil) }

    it "informs the correct expiration date" do
      email_body = mail.html_part.body.to_s.squish
      expect(email_body).to include("This invitation will expire on #{expiration_date} (two weeks).")
    end
  end
end
