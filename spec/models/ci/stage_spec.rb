require 'spec_helper'

describe Ci::Stage, models: true do
  let(:stage) { build(:ci_stage) }
  let(:pipeline) { stage.pipeline }
  let(:stage_name) { stage.name }

  describe '#expectations' do
    subject { stage }

    it { is_expected.to include_module(StaticModel) }

    it { is_expected.to respond_to(:pipeline) }
    it { is_expected.to respond_to(:name) }

    it { is_expected.to delegate_method(:project).to(:pipeline) }
  end

  describe '#statuses' do
    let!(:stage_build) { create_job(:ci_build) }
    let!(:commit_status) { create_job(:commit_status) }
    let!(:other_build) { create_job(:ci_build, stage: 'other stage') }

    subject { stage.statuses }

    it "returns only matching statuses" do
      is_expected.to contain_exactly(stage_build, commit_status)
    end
  end

  describe '#statuses_count' do
    before do
      create_job(:ci_build)
      create_job(:ci_build, stage: 'other stage')
    end

    subject { stage.statuses_count }

    it "counts statuses only from current stage" do
      is_expected.to eq(1)
    end
  end

  describe '#builds' do
    let!(:stage_build) { create_job(:ci_build) }
    let!(:commit_status) { create_job(:commit_status) }

    subject { stage.builds }

    it "returns only builds" do
      is_expected.to contain_exactly(stage_build)
    end
  end

  describe '#status' do
    subject { stage.status }

    context 'if status is already defined' do
      let(:stage) { build(:ci_stage, status: 'success') }

      it "returns defined status" do
        is_expected.to eq('success')
      end
    end

    context 'if status has to be calculated' do
      let!(:stage_build) { create_job(:ci_build, status: :failed) }

      it "returns status of a build" do
        is_expected.to eq('failed')
      end

      context 'and builds are retried' do
        let!(:new_build) { create_job(:ci_build, status: :success) }

        it "returns status of latest build" do
          is_expected.to eq('success')
        end
      end
    end
  end

  describe '#detailed_status' do
    let(:user) { create(:user) }

    subject { stage.detailed_status(user) }

    context 'when build is created' do
      let!(:stage_build) { create_job(:ci_build, status: :created) }

      it 'returns detailed status for created stage' do
        expect(subject.text).to eq 'created'
      end
    end

    context 'when build is pending' do
      let!(:stage_build) { create_job(:ci_build, status: :pending) }

      it 'returns detailed status for pending stage' do
        expect(subject.text).to eq 'pending'
      end
    end

    context 'when build is running' do
      let!(:stage_build) { create_job(:ci_build, status: :running) }

      it 'returns detailed status for running stage' do
        expect(subject.text).to eq 'running'
      end
    end

    context 'when build is successful' do
      let!(:stage_build) { create_job(:ci_build, status: :success) }

      it 'returns detailed status for successful stage' do
        expect(subject.text).to eq 'passed'
      end
    end

    context 'when build is failed' do
      let!(:stage_build) { create_job(:ci_build, status: :failed) }

      it 'returns detailed status for failed stage' do
        expect(subject.text).to eq 'failed'
      end
    end

    context 'when build is canceled' do
      let!(:stage_build) { create_job(:ci_build, status: :canceled) }

      it 'returns detailed status for canceled stage' do
        expect(subject.text).to eq 'canceled'
      end
    end

    context 'when build is skipped' do
      let!(:stage_build) { create_job(:ci_build, status: :skipped) }

      it 'returns detailed status for skipped stage' do
        expect(subject.text).to eq 'skipped'
      end
    end
  end

  describe '#success?' do
    context 'when stage is successful' do
      before do
        create_job(:ci_build, status: :success)
        create_job(:generic_commit_status, status: :success)
      end

      it 'is successful' do
        expect(stage).to be_success
      end
    end

    context 'when stage is not successful' do
      before do
        create_job(:ci_build, status: :failed)
        create_job(:generic_commit_status, status: :success)
      end

      it 'is not successful' do
        expect(stage).not_to be_success
      end
    end
  end

  describe '#has_warnings?' do
    context 'when stage has warnings' do
      context 'when using memoized warnings flag' do
        context 'when there are warnings' do
          let(:stage) { build(:ci_stage, warnings: true) }

          it 'has memoized warnings' do
            expect(stage).not_to receive(:statuses)
            expect(stage).to have_warnings
          end
        end

        context 'when there are no warnings' do
          let(:stage) { build(:ci_stage, warnings: false) }

          it 'has memoized warnings' do
            expect(stage).not_to receive(:statuses)
            expect(stage).not_to have_warnings
          end
        end
      end

      context 'when calculating warnings from statuses' do
        before do
          create(:ci_build, :failed, :allowed_to_fail,
                 stage: stage_name, pipeline: pipeline)
        end

        it 'has warnings calculated from statuses' do
          expect(stage).to receive(:statuses).and_call_original
          expect(stage).to have_warnings
        end
      end
    end

    context 'when stage does not have warnings' do
      before do
        create(:ci_build, :success, stage: stage_name,
                                    pipeline: pipeline)
      end

      it 'does not have warnings calculated from statuses' do
        expect(stage).to receive(:statuses).and_call_original
        expect(stage).not_to have_warnings
      end
    end
  end

  def create_job(type, status: 'success', stage: stage_name)
    create(type, pipeline: pipeline, stage: stage, status: status)
  end
end
