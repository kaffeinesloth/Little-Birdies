"use client";

import { useEffect, useRef, useState } from "react";
import { Loader2, RefreshCcw, Upload } from "lucide-react";
import { ApiClientError, apiClient } from "@/lib/api-client";
import { documents as mockDocuments } from "@/lib/mock-data";
import type { KnowledgeDocument } from "@/lib/types";
import { useAuth } from "./auth-provider";
import { PageHeader, Panel, StatusBadge } from "./ui";
import { SuperAdminSection } from "./super-admin-section";

const MAX_FILE_SIZE = 10 * 1024 * 1024;
const supportedTypes = new Set(["pdf", "docx", "txt"]);

function fileType(name: string): KnowledgeDocument["fileType"] | null {
  const extension = name.split(".").pop()?.toLowerCase();
  return extension === "pdf" || extension === "docx" || extension === "txt" ? extension : null;
}

function messageFor(error: unknown) {
  if (error instanceof ApiClientError && error.status === 403) {
    return "You do not have permission to manage the Knowledge Base.";
  }
  return "Knowledge Base backend is unavailable. Local preview data is shown.";
}

export function KnowledgeBaseAdmin() {
  const { accessToken, isMock, user } = useAuth();
  const inputRef = useRef<HTMLInputElement | null>(null);
  const [documents, setDocuments] = useState<KnowledgeDocument[]>(mockDocuments);
  const [error, setError] = useState<string | null>(null);
  const [uploading, setUploading] = useState(false);
  const [retryingId, setRetryingId] = useState<string | null>(null);

  useEffect(() => {
    if (isMock || !accessToken) return;
    let active = true;
    async function loadDocuments() {
      try {
        const response = await apiClient.listDocuments(accessToken ?? undefined);
        if (active) setDocuments(response.items);
      } catch (loadError) {
        if (active) setError(messageFor(loadError));
      }
    }
    void loadDocuments();
    return () => {
      active = false;
    };
  }, [accessToken, isMock]);

  async function handleUpload(file: File | undefined) {
    if (!file) return;
    const type = fileType(file.name);
    if (!type || !supportedTypes.has(type)) {
      setError("Unsupported file type. Upload a PDF, DOCX, or TXT file.");
      return;
    }
    if (file.size > MAX_FILE_SIZE) {
      setError("File is too large. The upload limit is 10 MB.");
      return;
    }

    setUploading(true);
    setError(null);
    try {
      if (isMock || !accessToken) {
        const now = new Date().toISOString();
        setDocuments((current) => [
          {
            id: `doc-${Date.now()}`,
            name: file.name,
            fileType: type,
            status: "processing",
            chunkCount: 0,
            uploadedBy: user?.fullName ?? "Current user",
            updatedAt: now
          },
          ...current
        ]);
      } else {
        const uploaded = await apiClient.uploadDocument(file, accessToken);
        setDocuments((current) => [uploaded, ...current]);
      }
    } catch (uploadError) {
      setError(messageFor(uploadError));
    } finally {
      setUploading(false);
      if (inputRef.current) inputRef.current.value = "";
    }
  }

  async function retryDocument(document: KnowledgeDocument) {
    setRetryingId(document.id);
    setError(null);
    try {
      if (isMock || !accessToken) {
        setDocuments((current) =>
          current.map((item) =>
            item.id === document.id
              ? { ...item, status: "processing", updatedAt: new Date().toISOString() }
              : item
          )
        );
      } else {
        const retried = await apiClient.retryDocument(document.id, accessToken);
        setDocuments((current) => current.map((item) => (item.id === retried.id ? retried : item)));
      }
    } catch (retryError) {
      setError(
        retryError instanceof ApiClientError && retryError.status === 404
          ? "Retry is not supported by this backend yet."
          : messageFor(retryError)
      );
    } finally {
      setRetryingId(null);
    }
  }

  return (
    <SuperAdminSection>
      <PageHeader
        title="Knowledge Base"
        description="Upload policy, warranty, shipping, and product documents for RAG answers."
        actions={
          <>
            <input
              accept=".pdf,.docx,.txt"
              className="hidden"
              onChange={(event) => void handleUpload(event.target.files?.[0])}
              ref={inputRef}
              type="file"
            />
            <button
              className="inline-flex h-9 items-center gap-2 bg-brand px-3 text-sm font-semibold text-white focus-ring disabled:cursor-not-allowed disabled:bg-slate-400"
              disabled={uploading}
              onClick={() => inputRef.current?.click()}
              type="button"
            >
              {uploading ? <Loader2 className="animate-spin" size={16} /> : <Upload size={16} />}
              Upload
            </button>
          </>
        }
      />
      {error ? <div className="border-b border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">{error}</div> : null}
      <div className="p-4">
        <Panel title="Documents">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-sm">
              <thead className="border-b border-line text-xs uppercase text-slate-500">
                <tr>
                  <th className="py-2">Name</th>
                  <th className="py-2">Type</th>
                  <th className="py-2">Status</th>
                  <th className="py-2">Chunks</th>
                  <th className="py-2">Uploaded by</th>
                  <th className="py-2 text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {documents.map((document) => (
                  <tr key={document.id} className="border-b border-line last:border-0">
                    <td className="py-3 font-medium text-ink">{document.name}</td>
                    <td className="py-3 text-slate-700">{document.fileType.toUpperCase()}</td>
                    <td className="py-3">
                      <StatusBadge value={document.status} />
                    </td>
                    <td className="py-3 text-slate-700">{document.chunkCount}</td>
                    <td className="py-3 text-slate-700">{document.uploadedBy}</td>
                    <td className="py-3 text-right">
                      {document.status === "error" ? (
                        <button
                          className="inline-flex h-8 items-center gap-2 border border-line bg-white px-3 text-xs font-medium text-slate-700 focus-ring disabled:cursor-not-allowed disabled:opacity-50"
                          disabled={retryingId !== null}
                          onClick={() => void retryDocument(document)}
                          type="button"
                        >
                          {retryingId === document.id ? (
                            <Loader2 className="animate-spin" size={14} />
                          ) : (
                            <RefreshCcw size={14} />
                          )}
                          Retry
                        </button>
                      ) : (
                        <span className="text-xs text-slate-400">No action</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Panel>
      </div>
    </SuperAdminSection>
  );
}
