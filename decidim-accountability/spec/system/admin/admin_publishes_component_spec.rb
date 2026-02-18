# frozen_string_literal: true

require "spec_helper"

describe "Admin publishes component" do
  let(:manifest_name) { "accountability" }
  let!(:resource) { create(:result, component:) }

  # include_context "when publishing and unpublishing the component"
  # include_context "when cycling through publication states"

  let(:title) { translated(current_component.name) }
  # When resources are being created or modified, the following jobs are enqueued among the ones that we need to wait for.
  # When running in CI, we have situations when job processing takes longer, causing flaky tests.
  # Adding a list of exceptions here, helps us to avoid those situations.
  let(:job_exceptions) do
    [
      Decidim::MachineTranslationResourceJob,
      ActiveStorage::AnalyzeJob
    ]
  end

  context "when component is unpublished" do
    before do
      current_component.unpublish!
      current_component.participatory_space.try_add_to_index_as_search_resource

      visit decidim_admin_participatory_processes.components_path(current_component.participatory_space)
    end

    it "reindexes on publication" do
      Decidim::SearchableResource.where(resource:).delete_all
      expect(Decidim::SearchableResource.where(resource:).count).to be_zero

      within "tr", text: title do
        find("button[data-controller='dropdown']").click
        click_on "Publish"
      end

      expect(page).to have_admin_callout("The component has been successfully published")

      perform_enqueued_jobs(except: job_exceptions)

      expect(Decidim::SearchableResource.where(resource:).count).to be_positive
      expect(component.reload).to be_published
    end
  end

  context "when component is published" do
    before do
      current_component.publish!
      current_component.participatory_space.try_add_to_index_as_search_resource

      visit decidim_admin_participatory_processes.components_path(current_component.participatory_space)
    end

    it "removes records from index" do
      perform_enqueued_jobs(except: job_exceptions)

      expect(Decidim::SearchableResource.where(resource:).count).to be_positive

      within ".sidebar-menu" do
        click_on "Components"
      end

      within "tr", text: title do
        find("button[data-controller='dropdown']").click
        click_on "Hide from menu"
      end

      perform_enqueued_jobs(except: job_exceptions)

      expect(Decidim::SearchableResource.where(resource:).count).to be_positive

      within "tr", text: title do
        find("button[data-controller='dropdown']").click
        click_on "Unpublish"
      end

      expect(page).to have_admin_callout("The component has been successfully unpublished")

      perform_enqueued_jobs(except: job_exceptions)

      expect(Decidim::SearchableResource.where(resource:).count).to be_zero
      expect(current_component.reload).not_to be_published
    end
  end

  include_context "when managing a component as an admin" do
    let(:title) { translated(current_component.name) }

    it "cycles through unpublished and published states successfully" do
      visit decidim_admin_participatory_processes.components_path(current_component.participatory_space)

      within ".sidebar-menu" do
        click_on "Components"
      end

      within "tr", text: title do
        find("button[data-controller='dropdown']").click
        click_on "Hide from menu"
      end

      expect(page).to have_admin_callout("The component has been successfully hidden from the menu.")

      within "tr", text: title do
        find("button[data-controller='dropdown']").click
        click_on "Unpublish"
      end

      expect(page).to have_admin_callout("The component has been successfully unpublished")

      within "tr", text: title do
        find("button[data-controller='dropdown']").click
        click_on "Publish"
      end

      expect(page).to have_admin_callout("The component has been successfully published")
    end
  end
end
