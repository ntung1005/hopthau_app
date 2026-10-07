'use client';

// Công trình: một màn cho cả hai bên. Nhà thầu báo xong mốc, đề nghị phát sinh, xác nhận nhận tiền,
// trả lời đánh giá. Chủ nhà duyệt / trả lại mốc, đồng ý / từ chối phát sinh, đánh giá khi xong.

import { useParams } from 'next/navigation';
import { useState } from 'react';
import { api, type Json } from '@/lib/api';
import { errorMessage, parseMillions, vnd, vnDate } from '@/lib/format';
import { useApp, useAuthLoad } from '@/ui/app';
import {
  ContractorLine, Field, Icon, InfoPanel, Loaded, Pill, PhoneRow, PhotoGrid, PhotoPicker, SectionTitle, Segmented, Sheet, TopBar,
  statusOf, type StatusMap,
} from '@/ui/kit';
import { jobPlace, jobStatus, ReviewCard, reviewCriteria } from '@/ui/shared';

const milestoneStatus: StatusMap = {
  pending: ['Chưa làm', 'muted'],
  submitted: ['Chờ chủ nhà duyệt', 'accent'],
  approved: ['Đã nghiệm thu', 'success'],
  rejected: ['Chủ nhà trả lại', 'error'],
};

const changeStatus: StatusMap = {
  pending: ['Chờ chủ nhà quyết', 'accent'],
  approved: ['Đã đồng ý', 'success'],
  rejected: ['Không đồng ý', 'muted'],
};

type SheetState =
  | { kind: 'milestone'; m: Json }
  | { kind: 'reject'; m: Json }
  | { kind: 'change' }
  | { kind: 'review' }
  | { kind: 'reply'; current: string };

export default function JobPage() {
  const { id } = useParams<{ id: string }>();
  const { toast, showError } = useApp();
  const state = useAuthLoad<Json>(() => api.getAuth(`/jobs/${id}`), [id]);
  const [busy, setBusy] = useState(false);
  const [sheet, setSheet] = useState<SheetState | null>(null);

  const run = async (action: () => Promise<unknown>, done?: string) => {
    setBusy(true);
    try {
      await action();
      setSheet(null);
      if (done) toast(done);
      state.reload();
    } catch (e) {
      showError(e);
    } finally {
      setBusy(false);
    }
  };

  const approve = (m: Json) => {
    const pay = m.amount == null
      ? 'Thanh toán theo thoả thuận trực tiếp với nhà thầu.'
      : `Sau đó thanh toán ${vnd(m.amount)} cho nhà thầu theo thoả thuận.`;
    if (!confirm(`Nghiệm thu "${m.title}"?\n\nXác nhận phần việc này đã xong như cam kết. ${pay}`)) return;
    void run(() => api.postAuth(`/jobs/milestones/${m.id}/review`, { approve: true }), 'Đã nghiệm thu');
  };

  return (
    <>
      <TopBar title="Công trình" fallback="/cong-trinh" />
      <main className="page">
        <Loaded state={state}>
          {(job) => {
            const isOwner = job.role === 'owner';
            const active = job.status === 'active';
            const milestones: Json[] = job.milestones;
            const changes: Json[] = job.changes;
            const review: Json | null = job.review;
            const [label, tone] = statusOf(jobStatus, job.status);
            const other = isOwner ? job.contractor : job.owner;
            // Mốc đang mở: mốc đầu tiên chưa nghiệm thu.
            const openIndex = milestones.findIndex((m) => m.status !== 'approved');
            return (
              <>
                <InfoPanel>
                  <span className="t-title">{jobPlace(job)}</span>
                  {job.request?.package && <span className="muted">Gói: {job.request.package.name}</span>}
                  <span style={{ marginTop: 4 }}>
                    {isOwner ? <ContractorLine c={other} className="" /> : `Chủ nhà: ${other.full_name}`}
                  </span>
                  <Pill tone={tone}>{label}</Pill>
                </InfoPanel>
                {other.phone && <div className="gap-t"><PhoneRow phone={other.phone} /></div>}
                <div className="gap-t"><Summary job={job} /></div>

                <SectionTitle>
                  Mốc thi công ({milestones.filter((m) => m.status === 'approved').length}/{milestones.length})
                </SectionTitle>
                {milestones.map((m, i) => (
                  <Milestone key={m.id} m={m} isLast={i === milestones.length - 1}>
                    {!isOwner && active && i === openIndex && (m.status === 'pending' || m.status === 'rejected') && (
                      <button className="btn" disabled={busy} onClick={() => setSheet({ kind: 'milestone', m })}>Báo xong mốc này</button>
                    )}
                    {isOwner && m.status === 'submitted' && (
                      <>
                        <button className="btn" disabled={busy} onClick={() => approve(m)}>Nghiệm thu</button>
                        <button className="btn outline" disabled={busy} onClick={() => setSheet({ kind: 'reject', m })}>Trả lại, cần sửa</button>
                      </>
                    )}
                    {!isOwner && m.status === 'approved' && m.paid_at == null && m.amount != null && (
                      <button
                        className="btn outline"
                        disabled={busy}
                        onClick={() => run(() => api.postAuth(`/jobs/milestones/${m.id}/paid`), 'Đã ghi nhận')}
                      >
                        Xác nhận đã nhận tiền
                      </button>
                    )}
                  </Milestone>
                ))}

                {/* Làm việc trực tiếp: giá và phát sinh thoả thuận bên ngoài, app chỉ theo dõi mốc. */}
                {!job.offline && (
                  <>
                    <SectionTitle>Phát sinh ({changes.length})</SectionTitle>
                    <p className="muted small" style={{ marginBottom: 8 }}>
                      Mọi thay đổi giá hoặc thời gian chỉ có hiệu lực khi chủ nhà đồng ý trong app.
                    </p>
                    {changes.map((c) => (
                      <ChangeCard
                        key={c.id}
                        change={c}
                        onDecide={isOwner && c.status === 'pending' && !busy
                          ? (ok) => run(() => api.postAuth(`/jobs/changes/${c.id}/decide`, { approve: ok }),
                            ok ? 'Đã đồng ý phát sinh' : 'Đã từ chối phát sinh')
                          : undefined}
                      />
                    ))}
                    {!isOwner && active && (
                      <button className="btn outline block gap-t8" disabled={busy} onClick={() => setSheet({ kind: 'change' })}>
                        <Icon name="add" /> Đề nghị phát sinh
                      </button>
                    )}
                  </>
                )}

                {job.status === 'completed' && (
                  <>
                    <SectionTitle>Đánh giá</SectionTitle>
                    {review ? (
                      <ReviewCard
                        review={review}
                        onReply={isOwner || busy ? undefined : () => setSheet({ kind: 'reply', current: review.reply ?? '' })}
                      />
                    ) : isOwner ? (
                      <button className="btn block" disabled={busy} onClick={() => setSheet({ kind: 'review' })}>
                        <Icon name="star" /> Đánh giá nhà thầu
                      </button>
                    ) : (
                      <p className="muted">Chủ nhà chưa đánh giá.</p>
                    )}
                  </>
                )}
              </>
            );
          }}
        </Loaded>
      </main>

      <Sheet open={!!sheet} onClose={() => setSheet(null)}>
        {sheet?.kind === 'milestone' && (
          <MilestoneForm
            m={sheet.m}
            busy={busy}
            onDone={(note, photos) => run(() => api.postAuth(`/jobs/milestones/${sheet.m.id}/submit`, { note, photos }), 'Đã báo chủ nhà nghiệm thu')}
          />
        )}
        {sheet?.kind === 'reject' && (
          <TextForm
            title={`Trả lại mốc "${sheet.m.title}"`}
            label="Cần sửa gì?"
            busy={busy}
            onDone={(t) => run(() => api.postAuth(`/jobs/milestones/${sheet.m.id}/review`, { approve: false, feedback: t }), 'Đã gửi góp ý cho nhà thầu')}
          />
        )}
        {sheet?.kind === 'reply' && (
          <TextForm
            title="Trả lời đánh giá"
            label="Lời trả lời công khai"
            initial={sheet.current}
            busy={busy}
            onDone={(t) => run(() => api.postAuth(`/jobs/${id}/review/reply`, { reply: t }), 'Đã trả lời')}
          />
        )}
        {sheet?.kind === 'change' && (
          <ChangeForm busy={busy} onDone={(body) => run(() => api.postAuth(`/jobs/${id}/changes`, body), 'Đã gửi đề nghị phát sinh cho chủ nhà')} />
        )}
        {sheet?.kind === 'review' && (
          <ReviewForm busy={busy} onDone={(body) => run(() => api.postAuth(`/jobs/${id}/review`, body), 'Cảm ơn bạn đã đánh giá!')} />
        )}
      </Sheet>
    </>
  );
}

function Summary({ job }: { job: Json }) {
  if (job.offline) {
    return (
      <InfoPanel>
        <Pill tone="accent">Làm việc trực tiếp</Pill>
        <p className="muted small gap-t8">
          Giá và thanh toán do hai bên thoả thuận bên ngoài. App theo dõi tiến độ các mốc: nhà thầu báo xong kèm ảnh, chủ nhà nghiệm thu.
        </p>
        {job.warranty_until && <span className="success gap-t8">Bảo hành đến {vnDate(job.warranty_until)}</span>}
      </InfoPanel>
    );
  }
  const { total, paid_amount: paid, approved_amount: approved } = job;
  const row = (label: string, value: string, cls = '') => (
    <div className="row" style={{ padding: '3px 0' }}>
      <span className="muted grow">{label}</span>
      <b className={cls}>{value}</b>
    </div>
  );
  return (
    <div className="card pad">
      {row('Tổng hợp đồng', vnd(total), 'primary')}
      {total !== job.price && row('Giá ban đầu', vnd(job.price))}
      {row('Đã nghiệm thu', vnd(approved))}
      {row('Nhà thầu đã nhận', vnd(paid), 'success')}
      {row('Thời gian', `${job.total_days} ngày`)}
      {job.warranty_until
        ? row('Bảo hành đến', vnDate(job.warranty_until), 'success')
        : row('Bảo hành', `${job.warranty_months} tháng sau bàn giao`)}
      <div className="progress gap-t8">
        <span style={{ width: `${total ? Math.min(Math.max(approved / total, 0), 1) * 100 : 0}%` }} />
      </div>
    </div>
  );
}

/** Một mốc trên dòng thời gian: vòng số thứ tự + đường nối, nội dung, ảnh, nút hành động. */
function Milestone({ m, isLast, children }: { m: Json; isLast: boolean; children: React.ReactNode }) {
  const [label, tone] = statusOf(milestoneStatus, m.status);
  const done = m.status === 'approved';
  return (
    <div className="timeline">
      <div className="timeline-rail">
        <span className={`timeline-dot${done ? ' done' : ''}`}>{done ? <Icon name="check" size={18} /> : m.seq}</span>
        {!isLast && <span className={`timeline-line${done ? ' done' : ''}`} />}
      </div>
      <div className="timeline-body">
        <div className="row">
          <span className="t-title grow">{m.title}</span>
          {m.amount != null && <b>{vnd(m.amount)}</b>}
        </div>
        <div className="row wrap">
          <Pill tone={tone}>{label}</Pill>
          {m.paid_at && <Pill tone="success">Đã thanh toán</Pill>}
        </div>
        {m.note && <p className="pre">{m.note}</p>}
        {m.photos.length > 0 && <PhotoGrid urls={m.photos} size={72} />}
        {m.owner_feedback && <div className="note-box err">Chủ nhà: {m.owner_feedback}</div>}
        {children}
      </div>
    </div>
  );
}

function ChangeCard({ change: c, onDecide }: { change: Json; onDecide?: (approve: boolean) => void }) {
  const [label, tone] = statusOf(changeStatus, c.status);
  const amount: number = c.amount, days: number = c.days_delta;
  return (
    <div className="card pad stack-8">
      <div className="row">
        <span className="t-title grow">{c.title}</span>
        <Pill tone={tone}>{label}</Pill>
      </div>
      <b className={amount >= 0 ? 'error' : 'success'}>
        {amount >= 0 ? '+' : '−'}{vnd(Math.abs(amount))}
        {days !== 0 && ` · ${days > 0 ? '+' : ''}${days} ngày`}
      </b>
      {c.description && <p className="pre">{c.description}</p>}
      {onDecide && (
        <div className="btn-row gap-t8">
          <button className="btn outline" onClick={() => onDecide(false)}>Từ chối</button>
          <button className="btn" onClick={() => onDecide(true)}>Đồng ý</button>
        </div>
      )}
    </div>
  );
}

// Form trong bottom sheet -----------------------------------------------------------

function MilestoneForm({ m, busy, onDone }: { m: Json; busy: boolean; onDone: (note: string, photos: string[]) => void }) {
  const [note, setNote] = useState<string>(m.note ?? '');
  const [photos, setPhotos] = useState<string[]>(m.photos ?? []);
  return (
    <>
      <h2 className="sheet-title">Báo xong: {m.title}</h2>
      <p className="muted">Chụp ảnh thực tế để chủ nhà nghiệm thu từ xa.</p>
      <Field label="Ghi chú"><textarea rows={3} maxLength={2000} value={note} onChange={(e) => setNote(e.target.value)} /></Field>
      <PhotoPicker photos={photos} onChange={setPhotos} />
      <button className="btn" disabled={busy} onClick={() => onDone(note, photos)}>Gửi chủ nhà nghiệm thu</button>
    </>
  );
}

function ChangeForm({ busy, onDone }: { busy: boolean; onDone: (body: Json) => void }) {
  const { toast } = useApp();
  const [f, setF] = useState({ title: '', description: '', amount: '', days: '0' });
  const [reduce, setReduce] = useState(false);
  const done = () => {
    const amount = parseMillions(f.amount);
    const days = /^-?\d+$/.test(f.days.trim()) ? parseInt(f.days, 10) : null;
    if (!f.title.trim()) return toast(errorMessage('missing_title'));
    if (amount == null) return toast(errorMessage('invalid_amount'));
    if (days == null) return toast(errorMessage('invalid_days_delta'));
    onDone({ title: f.title.trim(), description: f.description.trim(), amount: reduce ? -amount : amount, days_delta: days });
  };
  return (
    <>
      <h2 className="sheet-title">Đề nghị phát sinh</h2>
      <Field label="Nội dung"><input placeholder="Thêm kệ ban công" value={f.title} onChange={(e) => setF({ ...f, title: e.target.value })} /></Field>
      <Field label="Lý do, chi tiết">
        <textarea rows={3} value={f.description} onChange={(e) => setF({ ...f, description: e.target.value })} />
      </Field>
      <Segmented value={reduce} onChange={setReduce} options={[[false, 'Tăng tiền', 'add'], [true, 'Giảm tiền', 'remove']]} />
      <div className="form-row">
        <Field label="Số tiền (triệu)"><input inputMode="decimal" value={f.amount} onChange={(e) => setF({ ...f, amount: e.target.value })} /></Field>
        <Field label="Thêm ngày"><input inputMode="numeric" value={f.days} onChange={(e) => setF({ ...f, days: e.target.value })} /></Field>
      </div>
      <button className="btn" disabled={busy} onClick={done}>Gửi chủ nhà</button>
    </>
  );
}

function ReviewForm({ busy, onDone }: { busy: boolean; onDone: (body: Json) => void }) {
  const [scores, setScores] = useState<Record<string, number>>(Object.fromEntries(Object.keys(reviewCriteria).map((k) => [k, 5])));
  const [content, setContent] = useState('');
  const [photos, setPhotos] = useState<string[]>([]);
  return (
    <>
      <h2 className="sheet-title">Đánh giá nhà thầu</h2>
      <p className="muted">Đánh giá hiển thị công khai trên hồ sơ nhà thầu.</p>
      {Object.entries(reviewCriteria).map(([key, label]) => (
        <div key={key} className="row">
          <span className="grow">{label}</span>
          <span className="stars">
            {[1, 2, 3, 4, 5].map((i) => (
              <button key={i} title={`${i} sao`} aria-label={`${label} ${i} sao`} onClick={() => setScores({ ...scores, [key]: i })}>
                <Icon name="star" fill={i <= scores[key]} />
              </button>
            ))}
          </span>
        </div>
      ))}
      <Field label="Chia sẻ trải nghiệm">
        <textarea rows={4} maxLength={3000} value={content} onChange={(e) => setContent(e.target.value)} />
      </Field>
      <PhotoPicker photos={photos} onChange={setPhotos} />
      <button className="btn" disabled={busy} onClick={() => onDone({ ...scores, content, photos })}>Gửi đánh giá</button>
    </>
  );
}

function TextForm({ title, label, initial = '', busy, onDone }: {
  title: string; label: string; initial?: string; busy: boolean; onDone: (text: string) => void;
}) {
  const [text, setText] = useState(initial);
  return (
    <>
      <h2 className="sheet-title">{title}</h2>
      <Field label={label}>
        <textarea autoFocus rows={4} maxLength={2000} value={text} onChange={(e) => setText(e.target.value)} />
      </Field>
      <button className="btn" disabled={busy || !text.trim()} onClick={() => onDone(text.trim())}>Gửi</button>
    </>
  );
}
